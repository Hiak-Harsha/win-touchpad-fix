@echo off
title WinTouchpadFix - Instant Revive
echo ======================================================
echo       WinTouchpadFix: Instant Touchpad Revive
echo ======================================================
echo.

:: Ensure Administrator privileges (pnputil /restart-device requires elevation)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [*] Requesting Administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Restart exact I2C Host Controllers & Touchpad ACPI nodes (pnputil does not support wildcards)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'SilentlyContinue';" ^
  "Write-Host '[*] Power-cycling Serial IO I2C Host Controllers...';" ^
  "$ctrls = Get-PnpDevice | Where-Object { $_.FriendlyName -match 'I2C Host Controller' -or $_.Service -match '^iaLPSS2_I2C|^amd_i2c' };" ^
  "foreach ($c in $ctrls) { Write-Host ('    -> ' + $c.InstanceId); pnputil /restart-device $c.InstanceId | Out-Null };" ^
  "Write-Host '[*] Power-cycling Touchpad Hardware Nodes...';" ^
  "$tps = Get-PnpDevice | Where-Object { $_.InstanceId -match '^ACPI\\(ELAN|SYNA|SYN|GDX|GXTP|FTE|MSFT0001|COMP0001|PNP0C50)' -or $_.Service -eq 'hidi2c' };" ^
  "foreach ($t in $tps) { Write-Host ('    -> ' + $t.InstanceId); pnputil /restart-device $t.InstanceId | Out-Null };" ^
  "Write-Host '[*] Rescanning hardware bus...';" ^
  "pnputil /scan-devices | Out-Null;" ^
  "reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad\Status' /v Enabled /t REG_DWORD /d 1 /f | Out-Null;" ^
  "$after = Get-PnpDevice | Where-Object { $_.InstanceId -match '^ACPI\\(ELAN|SYNA|SYN|GDX|GXTP|FTE|MSFT0001|COMP0001|PNP0C50)' -or $_.Service -eq 'hidi2c' };" ^
  "$ok = $after -and -not ($after | Where-Object { $_.Status -ne 'OK' });" ^
  "Add-Type -AssemblyName System.Windows.Forms;" ^
  "$n = New-Object System.Windows.Forms.NotifyIcon;" ^
  "$n.Icon = [System.Drawing.SystemIcons]::Information;" ^
  "$n.Visible = $true;" ^
  "if ($ok) { Write-Host '`n[OK] Touchpad revived successfully!' -ForegroundColor Green; $n.ShowBalloonTip(2000, 'WinTouchpadFix', 'Touchpad I2C bus successfully revived!', [System.Windows.Forms.ToolTipIcon]::Info) } else { Write-Host '`n[!] Touchpad still reports an error. Full shutdown (unplug + hold power 10s) may be needed.' -ForegroundColor Yellow; $n.ShowBalloonTip(3000, 'WinTouchpadFix', 'Touchpad still in Error state - full power cycle recommended.', [System.Windows.Forms.ToolTipIcon]::Warning) };" ^
  "Start-Sleep -Seconds 1; $n.Dispose()"

timeout /t 3 >nul
exit /b
