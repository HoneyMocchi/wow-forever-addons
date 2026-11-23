$ErrorActionPreference = 'Stop'
$powershellBinary = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$watcherScript = Join-Path $PSScriptRoot 'GPT-AutoWatch.ps1'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$command = '"{0}" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{1}"' -f $powershellBinary, $watcherScript

# 현재 사용자 로그인 때만 감시자를 켠다. 관리자 권한, 시스템 서비스, 다른 시작 항목은 사용하지 않는다.
if (-not (Test-Path -LiteralPath $runKey)) { New-Item -Path $runKey | Out-Null }
New-ItemProperty -LiteralPath $runKey -Name 'WoWForeverGPT.AutoWatch' -PropertyType String -Value $command -Force | Out-Null
$arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}"' -f $watcherScript
# 사용자 세션에서만 실행하는 예약 작업으로 감시자 자체도 복구한다.
# 매분 트리거는 실행 중인 작업을 중복 시작하지 않으며, 감시자가 종료된 경우에만 다시 시작한다.
# 로그인 시 시작 항목은 호환용으로 유지하고, 경로별 mutex가 중복 감시자를 차단한다.
$taskName = 'WoWForeverGPT.AutoWatch'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute $powershellBinary -Argument ('-WindowStyle Hidden ' + $arguments) -WorkingDirectory $PSScriptRoot
$triggers = @(
    (New-ScheduledTaskTrigger -AtLogOn -User $identity),
    (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1))
)
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Write-Host '와우 포에버와 와우 AI 연결 프로그램의 자동 시작/종료를 켰습니다.'
