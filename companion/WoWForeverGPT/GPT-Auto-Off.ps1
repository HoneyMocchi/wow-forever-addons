$ErrorActionPreference = 'Stop'
# 먼저 복구 작업을 제거해야 사용자가 끈 감시자가 1분 뒤 다시 켜지지 않는다.
$task = Get-ScheduledTask -TaskName 'WoWForeverGPT.AutoWatch' -ErrorAction SilentlyContinue
if ($task) {
    Stop-ScheduledTask -TaskName $task.TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
}
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
# 이 애드온의 시작 항목 하나만 제거한다. 다른 프로그램의 자동 실행 설정은 유지한다.
Remove-ItemProperty -LiteralPath $runKey -Name 'WoWForeverGPT.AutoWatch' -ErrorAction SilentlyContinue
$runtimeFile = Join-Path $PSScriptRoot 'bridge/auto-watch-runtime.json'
if (Test-Path -LiteralPath $runtimeFile) {
    $runtime = Get-Content -LiteralPath $runtimeFile -Raw | ConvertFrom-Json
    $watcherProcess = Get-Process -Id $runtime.processId -ErrorAction SilentlyContinue
    if ($watcherProcess -and $watcherProcess.Path -eq $runtime.executable -and
        $watcherProcess.StartTime.ToUniversalTime().Ticks.ToString() -eq $runtime.startTicks) {
        Stop-Process -Id $watcherProcess.Id
    }
}
Write-Host '자동 연동을 껐습니다. 실행 중인 GPT는 GPT-Stop.cmd로 종료할 수 있습니다.'
