param([switch]$KeepAlive, [switch]$SkipAuthCheck)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) {
    Write-Host 'Node.js 22 이상을 설치해 주세요.'
    exit 1
}
if (-not (Test-Path -LiteralPath 'bridge/config.json' -PathType Leaf)) {
    Write-Host 'Install.cmd를 먼저 실행해 주세요.'
    exit 1
}

# 같은 브리지를 두 번 실행하면 질문이 중복 처리될 수 있다.
# PID뿐 아니라 실행 파일과 시작 시간도 비교하여 재사용된 다른 프로세스는 건드리지 않는다.
$runtimeFile = Join-Path $PSScriptRoot 'bridge/runtime.json'
if (Test-Path -LiteralPath $runtimeFile) {
    $previous = Get-Content -LiteralPath $runtimeFile -Raw | ConvertFrom-Json
    $runningBridge = Get-Process -Id $previous.processId -ErrorAction SilentlyContinue
    if ($runningBridge -and $runningBridge.Path -eq $previous.executable -and
        $runningBridge.StartTime.ToUniversalTime().Ticks.ToString() -eq $previous.startTicks) {
        Write-Host '와우 AI 연결 프로그램이 이미 실행 중입니다.'
        exit 0
    }
}

# 자동 복구는 로그인 사전 검사에 의존하지 않는다. 실제 질문 시 각 AI가 인증 오류를 보고한다.
# 연결 유지와 모델 로그인을 분리해야 네트워크/CLI의 일시 오류가 전체 연결을 막지 않는다.
if (-not $SkipAuthCheck) {
    & node.exe bridge/bridge.js --auth-check
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# 콘솔 창은 숨기고 진단 로그를 남긴다. 로그인 자동 실행이나 예약 작업은 만들지 않는다.
# 종료할 때에는 GPT-Stop.cmd가 이 프로세스와 화면 전송용 자식 프로세스만 종료한다.
$nodeBinary = (Get-Command node.exe).Source
$bridgeScript = Join-Path $PSScriptRoot 'bridge/bridge.js'
$bridgeProcess = Start-Process -FilePath $nodeBinary -ArgumentList @('"' + $bridgeScript + '"') `
    -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $PSScriptRoot 'bridge/console.log') `
    -RedirectStandardError (Join-Path $PSScriptRoot 'bridge/console-error.log')
[PSCustomObject]@{
    processId = $bridgeProcess.Id
    executable = $nodeBinary
    startTicks = $bridgeProcess.StartTime.ToUniversalTime().Ticks.ToString()
} | ConvertTo-Json | Set-Content -LiteralPath $runtimeFile -Encoding utf8
Write-Host '와우 AI 연결 프로그램을 켰습니다. 게임에서 /ai 질문을 입력하세요.'
# 부모 종료 시 자식도 정리하는 실행 환경에서는 호스트를 유지한다.
# 탐색기에서 CMD를 직접 실행하는 일반 사용에는 필요하지 않다.
if ($KeepAlive) { $bridgeProcess.WaitForExit() }
exit 0
