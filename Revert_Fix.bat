@echo off
setlocal EnableDelayedExpansion

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [WinTouchpadFix] Requesting Administrator privileges to revert settings...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/k \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

title WinTouchpadFix - Revert to Factory Defaults
color 0E
cls

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinTouchpadFix.ps1" -Revert

echo.
echo Press any key to exit...
pause >nul
