param(
    [string]$ProjectRoot = $PSScriptRoot,
    [int]$PollSeconds = 3,
    [int]$RetrySeconds = 30
)
$ErrorActionPreference = 'Stop'
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$bridgeFolder = Join-Path $ProjectRoot 'bridge'
$watchRuntime = Join-Path $bridgeFolder 'auto-watch-runtime.json'
$logFile = Join-Path $bridgeFolder 'auto-watch.log'
$powershellBinary = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Write-WatchLog([string]$Text) {
    Add-Content -LiteralPath $logFile -Encoding utf8 -Value ('[{0}] {1}' -f (Get-Date -Format o), $Text)
}

function Get-BridgeProcess {
    # PID가 다른 프로그램에 재사용되어도 기존 GPT 브리지로 오인하지 않는다.
    $file = Join-Path $bridgeFolder 'runtime.json'
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    try {
        $runtime = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        $candidate = Get-Process -Id $runtime.processId -ErrorAction SilentlyContinue
        if ($candidate -and $candidate.Path -eq $runtime.executable -and
            $candidate.StartTime.ToUniversalTime().Ticks.ToString() -eq $runtime.startTicks) {
            return $candidate
        }
    } catch { }
    return $null
}

function Invoke-Companion([string]$FileName) {
    $file = Join-Path $ProjectRoot $FileName
    $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $file
    if ($FileName -eq 'GPT-Start.ps1') { $arguments += ' -SkipAuthCheck' }
    # -Wait는 손자 프로세스인 브리지까지 기다리므로 사용하지 않는다.
    # 시작 스크립트 프로세스만 기다려야 게임 종료 감시를 곧바로 계속할 수 있다.
    $helper = Start-Process -FilePath $powershellBinary -ArgumentList $arguments `
        -WorkingDirectory $ProjectRoot -WindowStyle Hidden -PassThru
    $null = $helper.Handle
    # 시작 도우미가 멈춰도 감시 루프까지 영구 정지하지 않도록 상한을 둔다.
    if (-not $helper.WaitForExit(45000)) {
        Stop-Process -Id $helper.Id -ErrorAction SilentlyContinue
        throw "$FileName timed out"
    }
    if ($helper.ExitCode -ne 0) { throw "$FileName exited with $($helper.ExitCode)" }
}

# 설치 위치별로 감시자를 하나만 허용한다. 같은 시작 항목을 두 번 실행해도 중복되지 않는다.
$sha = [Security.Cryptography.SHA256]::Create()
try { $key = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($ProjectRoot.ToLowerInvariant()))).Replace('-', '') }
finally { $sha.Dispose() }
$mutex = New-Object Threading.Mutex($false, ('Local\WoWForeverGPT-AutoWatch-' + $key))
$ownsMutex = $false
try {
    try { $ownsMutex = $mutex.WaitOne(0) }
    catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (-not $ownsMutex) { exit 0 }

    $config = Get-Content -LiteralPath (Join-Path $bridgeFolder 'config.json') -Raw | ConvertFrom-Json
    $clientFolder = Split-Path -Parent (Split-Path -Parent $config.addonDir)
    $gameName = [IO.Path]::GetFileNameWithoutExtension([string]$config.capture.processName)
    $gameExecutable = [IO.Path]::GetFullPath((Join-Path $clientFolder ($gameName + '.exe')))
    if (-not (Test-Path -LiteralPath $gameExecutable)) { throw "Game executable not found: $gameExecutable" }

    $self = Get-Process -Id $PID
    [PSCustomObject]@{
        processId = $PID
        executable = $self.Path
        startTicks = $self.StartTime.ToUniversalTime().Ticks.ToString()
        projectRoot = $ProjectRoot
    } | ConvertTo-Json | Set-Content -LiteralPath $watchRuntime -Encoding utf8
    Write-WatchLog "Watcher started; client=$gameExecutable"

    $previousGameState = $null
    $nextAttempt = [DateTime]::MinValue
    while ($true) {
        try {
            # 프로세스 이름과 실제 실행 경로를 모두 확인한다. 리테일/다른 클래식은 제외한다.
            # 모든 프로세스를 열거하거나 WMI 감사를 켜지 않고 해당 이름만 3초마다 확인한다.
            $gameProcesses = @(Get-Process -Name $gameName -ErrorAction SilentlyContinue | Where-Object {
                try { $_.Path -and [IO.Path]::GetFullPath($_.Path) -eq $gameExecutable } catch { $false }
            })
            $gameRunning = $gameProcesses.Count -gt 0
            if ($previousGameState -ne $gameRunning) {
                Write-WatchLog ('Game ' + $(if ($gameRunning) { 'running' } else { 'closed' }))
                $previousGameState = $gameRunning
                $nextAttempt = [DateTime]::MinValue
            }

            $bridge = Get-BridgeProcess
            if ($gameRunning -and $bridge) {
                # PID가 살아 있어도 이벤트 루프가 멈추면 연결은 죽어 있다.
                # 시작 직후에는 90초 유예하고, 실행 PID가 일치하는 최근 하트비트만 신뢰한다.
                $unhealthy = $false
                if (((Get-Date) - $bridge.StartTime).TotalSeconds -gt 90) {
                    try {
                        $health = Get-Content -LiteralPath (Join-Path $bridgeFolder 'health.json') -Raw | ConvertFrom-Json
                        $age = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - [double]$health.at) / 1000
                        $unhealthy = $health.processId -ne $bridge.Id -or $age -gt 90 -or $age -lt -30
                    } catch { $unhealthy = $true }
                }
                if ($unhealthy -and (Get-Date) -ge $nextAttempt) {
                    Write-WatchLog 'Bridge heartbeat stalled; restarting verified process tree'
                    Invoke-Companion 'GPT-Stop.ps1'
                    $bridge = $null
                }
            }
            if ($gameRunning -and -not $bridge -and (Get-Date) -ge $nextAttempt) {
                # 실패가 반복되어도 30초 이내에 다시 실행하지 않아 로그인 오류 팝업/프로세스 폭주를 막는다.
                $nextAttempt = (Get-Date).AddSeconds([Math]::Max(3, $RetrySeconds))
                Invoke-Companion 'GPT-Start.ps1'
                if (-not (Get-BridgeProcess)) { throw 'Bridge did not remain running' }
                Write-WatchLog 'Bridge started for game'
            } elseif (-not $gameRunning -and $bridge -and (Get-Date) -ge $nextAttempt) {
                $nextAttempt = (Get-Date).AddSeconds([Math]::Max(3, $RetrySeconds))
                # GPT-Stop은 기록된 브리지의 PID/시작 시간을 다시 검증하고 그 자식들만 정리한다.
                # 다른 Node/Codex 프로그램이나 게임 프로세스는 종료하지 않는다.
                Invoke-Companion 'GPT-Stop.ps1'
                Write-WatchLog 'Bridge stopped after game closed'
            }
        } catch {
            Write-WatchLog ('Error: ' + $_.Exception.Message)
        }
        Start-Sleep -Seconds ([Math]::Max(1, $PollSeconds))
    }
} catch {
    Write-WatchLog ('Fatal: ' + $_.Exception.Message)
    exit 1
} finally {
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
