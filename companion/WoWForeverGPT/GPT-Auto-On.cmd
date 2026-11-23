@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0GPT-Auto-On.ps1"
if errorlevel 1 pause
