@echo off
echo ==========================================
echo   Temurin LTS GUI - EXE Builder
echo ==========================================
echo.

:: Run the PowerShell build script using PowerShell 7
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-TemurinGUI.ps1"

echo.
pause
