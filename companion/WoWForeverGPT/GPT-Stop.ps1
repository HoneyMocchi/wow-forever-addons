$ErrorActionPreference = 'Stop'
$runtimeFile = Join-Path $PSScriptRoot 'bridge/runtime.json'
if (-not (Test-Path -LiteralPath $runtimeFile)) { Write-Host '실행 기록이 없습니다.'; exit 0 }
$runtime = Get-Content -LiteralPath $runtimeFile -Raw | ConvertFrom-Json
$bridgeProcess = Get-Process -Id $runtime.processId -ErrorAction SilentlyContinue
if (-not $bridgeProcess) { Write-Host '이미 종료되었습니다.'; exit 0 }

# PID 재사용으로 다른 Node 프로그램이 종료되지 않도록 실제 실행 파일과 시작 시간을 확인한다.
# /T는 이 브리지의 자식인 화면 전송·답변 처리 프로세스만 함께 정리한다.
if ($bridgeProcess.Path -ne $runtime.executable -or
    $bridgeProcess.StartTime.ToUniversalTime().Ticks.ToString() -ne $runtime.startTicks) {
    throw '실행 기록과 프로세스가 달라 종료하지 않았습니다.'
}
& taskkill.exe /PID $runtime.processId /T /F
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host '와우 AI 연결 프로그램을 종료했습니다.'
