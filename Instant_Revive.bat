@echo off
title WinTouchpadFix - Instant Revive
echo ======================================================
echo       WinTouchpadFix: Instant 2-Second Revive
echo ======================================================
echo.

:: 1. Force hardware power cycle on parent host controllers
echo [*] Power-cycling Serial IO I2C Host Controllers...
pnputil /restart-device "PCI\VEN_8086*" >nul 2>&1
pnputil /restart-device "PCI\VEN_1022*" >nul 2>&1

:: 2. Restart Touchpad ACPI nodes
echo [*] Power-cycling Touchpad Hardware Nodes...
pnputil /restart-device "ACPI\ELAN*" >nul 2>&1
pnputil /restart-device "ACPI\SYNA*" >nul 2>&1
pnputil /restart-device "ACPI\COMP0001*" >nul 2>&1

:: 3. Instant PnP device scan
echo [*] Rescanning hardware bus...
pnputil /scan-devices >nul 2>&1

:: 4. Ensure Precision Touchpad Status is Enabled
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad\Status" /v Enabled /t REG_DWORD /d 1 /f >nul 2>&1

:: 5. Native Windows Notification
powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $n = New-Object System.Windows.Forms.NotifyIcon; $n.Icon = [System.Drawing.SystemIcons]::Information; $n.Visible = $true; $n.ShowBalloonTip(2000, 'WinTouchpadFix', 'Touchpad I2C bus successfully revived!', [System.Windows.Forms.ToolTipIcon]::Info); Start-Sleep -Seconds 1; $n.Dispose()" >nul 2>&1

echo.
echo [OK] Touchpad revived successfully!
timeout /t 2 >nul
exit /b
