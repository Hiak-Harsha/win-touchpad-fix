@echo off
setlocal EnableDelayedExpansion

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [WinTouchpadFix] Requesting Administrator privileges to run hardware audit...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/k \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

title WinTouchpadFix - Hardware & Policy Audit
color 0B
cls

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WinTouchpadFix.ps1" -AuditOnly

echo.
echo Press any key to exit...
pause >nul
