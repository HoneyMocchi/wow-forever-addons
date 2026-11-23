@echo off
cd /d "%~dp0"
where node.exe >nul 2>&1
if errorlevel 1 (
  echo Install Node.js 22 or later from https://nodejs.org/ and try again.
  pause
  exit /b 1
)
node setup.js %*
set "result=%errorlevel%"
pause
exit /b %result%
