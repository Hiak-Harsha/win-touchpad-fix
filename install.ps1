# WinTouchpadFix - Quick Remote Installer
# Usage: irm https://raw.githubusercontent.com/Hiak-Harsha/win-touchpad-fix/main/install.ps1 | iex

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "WinTouchpadFix requires Administrator privileges to configure hardware parameters."
    Write-Host "Relaunching in an elevated PowerShell session..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/Hiak-Harsha/win-touchpad-fix/main/install.ps1 | iex`"" -Verb RunAs
    exit
}

$tempScript = "$env:TEMP\WinTouchpadFix.ps1"
Write-Host "Downloading latest WinTouchpadFix engine..." -ForegroundColor Cyan
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Hiak-Harsha/win-touchpad-fix/main/WinTouchpadFix.ps1" -OutFile $tempScript

Write-Host "Executing WinTouchpadFix..." -ForegroundColor Green
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tempScript
