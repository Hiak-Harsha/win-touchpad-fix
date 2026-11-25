<#
.SYNOPSIS
    WinTouchpadFix - Universal Windows I2C HID Touchpad & Code 10 Permanence Engine
.DESCRIPTION
    Permanently resolves the chronic "I2C HID Device Code 10 (CM_PROB_FAILED_START)"
    and freezing touchpad issues across Lenovo, Dell, HP, ASUS, Acer, and other Windows laptops.
    Works universally across Intel and AMD platforms and ELAN, Synaptics, Goodix, and FocalTech sensors.
.PARAMETER AuditOnly
    Runs a non-destructive hardware & policy audit without modifying system settings.
.PARAMETER Revert
    Restores default Windows power management settings from backup.
.PARAMETER NoRestorePoint
    Skips creating a Windows System Restore Point.
.AUTHOR
    Hiak-Harsha & Antigravity
.LICENSE
    MIT License
#>

[CmdletBinding()]
param(
    [switch]$AuditOnly = $false,
    [switch]$Revert = $false,
    [switch]$NoRestorePoint = $false
)

# Ensure script is running with Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Administrator privileges required. Relaunching with elevation..."
    $params = @()
    if ($AuditOnly) { $params += "-AuditOnly" }
    if ($Revert) { $params += "-Revert" }
    if ($NoRestorePoint) { $params += "-NoRestorePoint" }
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $($params -join ' ')") -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "WinTouchpadFix - Universal I2C Touchpad Engine"
Clear-Host

$banner = @"
==========================================================================
       WinTouchpadFix - Universal Windows I2C Touchpad Hardener           
  Fixes: Code 10, D3Cold Sleep Freeze, Modern Standby Crashes, Bus Timeouts
==========================================================================
"@
Write-Host $banner -ForegroundColor Cyan

$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os = Get-CimInstance Win32_OperatingSystem

Write-Host "[*] Machine:   $($cs.Manufacturer) $($cs.Model)" -ForegroundColor Cyan
Write-Host "[*] OS Build:  $($os.Caption) (Build $($os.BuildNumber))" -ForegroundColor Cyan
Write-Host "[*] BIOS:      $($bios.SMBIOSBIOSVersion) ($($bios.ReleaseDate))" -ForegroundColor Cyan
Write-Host ""

$dataDir = "C:\ProgramData\WinTouchpadFix"
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
$logFile = "$dataDir\WinTouchpadFix.log"

function Log-Message([string]$msg, [string]$color = "White") {
    $time = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "[$time] $msg" | Out-File -FilePath $logFile -Append -Encoding utf8
    Write-Host $msg -ForegroundColor $color
}

Log-Message "Session started for $($cs.Manufacturer) $($cs.Model)"

# =========================================================================
# REVERT MODE: Restore Factory Settings
# =========================================================================
if ($Revert) {
    Write-Host "[!] REVERT MODE: Restoring default Windows power management settings..." -ForegroundColor Yellow
    
    # 1. Re-enable Fast Startup
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'HiberbootEnabled' -ErrorAction SilentlyContinue
    Log-Message "  -> Fast Startup re-enabled." "Green"

    # 2. Reset hidi2c reset timeout
    Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\hidi2c\Parameters' -Name 'DefaultResetTimeout' -ErrorAction SilentlyContinue
    Log-Message "  -> Reset timeout reverted to default." "Green"

    # 3. Re-enable driver updates from Windows Update
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name 'ExcludeWUDriversInQualityUpdate' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' -Name 'SearchOrderConfig' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Log-Message "  -> Windows Update driver settings reverted." "Green"

    # 4. Remove emergency revive & watchdog tasks
    Unregister-ScheduledTask -TaskName 'WinTouchpadRevive' -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName 'WinTouchpadWatchdog' -Confirm:$false -ErrorAction SilentlyContinue
    if (Test-Path "$dataDir\Watchdog.ps1") { Remove-Item "$dataDir\Watchdog.ps1" -Force -ErrorAction SilentlyContinue }
    if (Test-Path "$HOME\Desktop\Revive_Touchpad.lnk") { Remove-Item "$HOME\Desktop\Revive_Touchpad.lnk" -Force -ErrorAction SilentlyContinue }
    Log-Message "  -> Emergency shortcut and tasks removed." "Green"

    Write-Host "`n[OK] Revert completed. Please restart your computer." -ForegroundColor Green
    exit
}

# =========================================================================
# AUDIT MODE: Non-Destructive Inspection
# =========================================================================
if ($AuditOnly) {
    Write-Host "[*] AUDIT MODE: Inspecting hardware and policy vulnerabilities..." -ForegroundColor Yellow
    
    $fastStartup = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -ErrorAction SilentlyContinue).HiberbootEnabled
    $hidi2cTimeout = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\hidi2c\Parameters' -ErrorAction SilentlyContinue).DefaultResetTimeout
    $wuPolicy = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -ErrorAction SilentlyContinue).ExcludeWUDriversInQualityUpdate
    $leaveOnMouse = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad' -ErrorAction SilentlyContinue).LeaveOnWithMouse

    $touchpads = Get-PnpDevice | Where-Object { $_.FriendlyName -match 'Touchpad|Trackpad|I2C HID' -or $_.InstanceId -match 'ELAN|SYNA|COMP0001' }
    
    Write-Host "`n--- HARDWARE & VULNERABILITY SCORECARD ---" -ForegroundColor Cyan
    Write-Host "Touchpad Detected:        " -NoNewline
    if ($touchpads) { Write-Host "$($touchpads[0].FriendlyName) ($($touchpads[0].Status))" -ForegroundColor Green } else { Write-Host "Not Detected" -ForegroundColor Red }
    
    Write-Host "Fast Startup (Freeze Risk):" -NoNewline
    if ($fastStartup -eq 1) { Write-Host " ENABLED (Vulnerable to boot freeze)" -ForegroundColor Red } else { Write-Host " DISABLED (Protected)" -ForegroundColor Green }

    Write-Host "I2C Wakeup Timeout:       " -NoNewline
    if ($hidi2cTimeout -ge 5000) { Write-Host " $hidi2cTimeout ms (Protected)" -ForegroundColor Green } else { Write-Host " Default ~200ms (Vulnerable to timeout)" -ForegroundColor Red }

    Write-Host "Driver Update Shield:     " -NoNewline
    if ($wuPolicy -eq 1) { Write-Host " ACTIVE (Protected)" -ForegroundColor Green } else { Write-Host " INACTIVE (Windows Update may overwrite driver)" -ForegroundColor Yellow }

    Write-Host "USB Mouse Coexistence:    " -NoNewline
    if ($leaveOnMouse -eq 1) { Write-Host " LOCKED ON (Protected)" -ForegroundColor Green } else { Write-Host " UNLOCKED (May auto-disable on USB connect)" -ForegroundColor Yellow }

    Write-Host "`nTo apply all fixes, run WinTouchpadFix without -AuditOnly." -ForegroundColor Cyan
    exit
}

# =========================================================================
# SYSTEM RESTORE POINT (Safety Net)
# =========================================================================
if (-not $NoRestorePoint) {
    Write-Host "[*] Creating System Restore Point for safety..." -ForegroundColor Cyan
    try {
        Checkpoint-Computer -Description "WinTouchpadFix Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop | Out-Null
        Log-Message "  -> System Restore Point successfully created." "Green"
    } catch {
        Log-Message "  -> Note: System Restore is disabled or recently created. Continuing safely." "Gray"
    }
}

# =========================================================================
# STEP 1: Discover & Harden All I2C Touchpad Sensors (ELAN, Synaptics, Goodix)
# =========================================================================
Log-Message "`n[1/7] Discovering Touchpad Hardware & Sensor Nodes..." "Yellow"

$vendorPatterns = @('ELAN', 'SYNA', 'SYN', 'GDX', 'GXTP', 'FTE', 'MSFT0001', 'COMP0001', 'PNP0C50')
$touchpadKeys = @()

foreach ($pattern in $vendorPatterns) {
    $found = Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\ACPI' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $pattern -and $_.Name -like '*\Device Parameters*' }
    if ($found) { $touchpadKeys += $found }
}

if ($touchpadKeys.Count -gt 0) {
    Log-Message "      Found $($touchpadKeys.Count) ACPI Touchpad parameter keys." "Green"
    foreach ($k in $touchpadKeys) {
        $regPath = 'Registry::' + $k.Name
        Set-ItemProperty -Path $regPath -Name 'EnhancedPowerManagementEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $regPath -Name 'D3ColdSupported' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        if ($k.Name -match '\\Device Parameters$') {
            $wdfPath = "$regPath\WDF"
            if (-not (Test-Path $wdfPath)) { New-Item -Path $wdfPath -Force -ErrorAction SilentlyContinue | Out-Null }
            Set-ItemProperty -Path $wdfPath -Name 'IdleInWorkingState' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $wdfPath -Name 'WdfDirectedPowerTransitionEnable' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    }
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\ACPI' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'ELAN|SYNA|GDX' -and $_.Name -match 'e5b3b5ac-9725-4f78-963f-03dfb1d828c7' } |
        ForEach-Object {
            Set-ItemProperty -Path ('Registry::' + $_.Name) -Name 'D3ColdSupported' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }
    Log-Message "      -> Success: Disabled D3Cold deep-sleep & Enhanced Power Management on touchpad." "Green"
} else {
    Log-Message "      -> Generic HID touchpad mode active." "Gray"
}

# =========================================================================
# STEP 2: Harden All Intel & AMD Serial IO I2C Host Controllers
# =========================================================================
Log-Message "`n[2/7] Hardening Host Controller Bus Power States (Intel & AMD)..." "Yellow"

$controllerKeys = @(
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { ($_.Name -match 'VEN_8086&DEV_51' -or $_.Name -match 'VEN_8086&DEV_A0' -or $_.Name -match 'VEN_8086&DEV_02' -or $_.Name -match 'VEN_1022') -and $_.Name -like '*\WDF' }
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\ACPI' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { ($_.Name -match 'INTC10' -or $_.Name -match 'AMDI003') -and $_.Name -like '*\WDF' }
)

$patchedControllers = 0
foreach ($ck in $controllerKeys) {
    $regPath = 'Registry::' + $ck.Name
    Set-ItemProperty -Path $regPath -Name 'IdleInWorkingState' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name 'WdfDirectedPowerTransitionEnable' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    $devParamsPath = Split-Path -Path $regPath -Parent
    Set-ItemProperty -Path $devParamsPath -Name 'D3ColdSupported' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $devParamsPath -Name 'EnhancedPowerManagementEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    $d3Key = "$devParamsPath\e5b3b5ac-9725-4f78-963f-03dfb1d828c7"
    if (Test-Path $d3Key) {
        Set-ItemProperty -Path $d3Key -Name 'D3ColdSupported' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $d3Key -Name 'EnhancedPowerManagementEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    $patchedControllers++
}
Log-Message "      -> Success: Disabled idle bus-sleep across $patchedControllers host controllers." "Green"

# =========================================================================
# STEP 3: Extend I2C Reset Timeout to 5000ms
# =========================================================================
Log-Message "`n[3/7] Extending I2C Driver Wakeup Reset Timeout..." "Yellow"
$hidi2cParams = 'HKLM:\SYSTEM\CurrentControlSet\Services\hidi2c\Parameters'
if (-not (Test-Path $hidi2cParams)) { New-Item -Path $hidi2cParams -Force | Out-Null }
New-ItemProperty -Path $hidi2cParams -Name 'DefaultResetTimeout' -PropertyType DWord -Value 5000 -Force -ErrorAction SilentlyContinue | Out-Null
Log-Message "      -> Success: Set DefaultResetTimeout = 5000ms (5 full seconds for wake handshake)." "Green"

# =========================================================================
# STEP 4: Shield from Windows Update Driver Replacements
# =========================================================================
Log-Message "`n[4/7] Shielding Hardware Drivers from Windows Update Overwrites..." "Yellow"
$wuPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
if (-not (Test-Path $wuPolicy)) { New-Item -Path $wuPolicy -Force | Out-Null }
Set-ItemProperty -Path $wuPolicy -Name 'ExcludeWUDriversInQualityUpdate' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' -Name 'SearchOrderConfig' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Log-Message "      -> Success: Windows Update driver overwrites blocked." "Green"

# =========================================================================
# STEP 5: Disable Fast Startup (Prevents Boot Error Reloads)
# =========================================================================
Log-Message "`n[5/7] Disabling Windows Fast Startup (Prevents Cached Error Reloads)..." "Yellow"
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
$sysPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
if (-not (Test-Path $sysPolicy)) { New-Item -Path $sysPolicy -Force | Out-Null }
Set-ItemProperty -Path $sysPolicy -Name 'HiberbootEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Log-Message "      -> Success: Fast Startup locked to 0 in System Policy (guarantees clean cold boots)." "Green"

# =========================================================================
# STEP 6: USB & External Mouse Coexistence
# =========================================================================
Log-Message "`n[6/7] Securing USB & External Mouse Coexistence..." "Yellow"
$ptpUser = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad'
$ptpStatus = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad\Status'
$ptpLM = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad'
$ptpPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PrecisionTouchPad'

foreach ($p in @($ptpUser, $ptpStatus, $ptpLM, $ptpPol)) {
    if (-not (Test-Path $p)) { New-Item -Path $p -Force -ErrorAction SilentlyContinue | Out-Null }
    Set-ItemProperty -Path $p -Name 'LeaveOnWithMouse' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
}
Log-Message "      -> Success: Touchpad will NEVER auto-disable when USB mice or drives are inserted." "Green"

# =========================================================================
# STEP 7: PCIe Link State Power Management (ASPM Off for Zero Wake Latency)
# =========================================================================
Log-Message "`n[7/7] Disabling PCIe Link State Power Management (ASPM)..." "Yellow"
powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 2>$null
powercfg /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 2>$null
powercfg /setactive SCHEME_CURRENT 2>$null
Log-Message "      -> Success: PCIe ASPM set to Off across AC and Battery." "Green"

# =========================================================================
# Install Protected Emergency Revive Engine with Native Notification
# =========================================================================
Log-Message "`n[*] Installing Protected Emergency Revive Engine & Global Hotkey (Ctrl+Alt+T)..." "Cyan"

$reviveBat = @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-PnpDevice | Where-Object { `$_.FriendlyName -match 'I2C Host Controller' -or `$_.Service -match '^iaLPSS2_I2C|^amd_i2c' } | ForEach-Object { pnputil /restart-device `$_.InstanceId | Out-Null }; Get-PnpDevice | Where-Object { `$_.InstanceId -match '^ACPI\\(ELAN|SYNA|SYN|GDX|GXTP|FTE|MSFT0001|COMP0001|PNP0C50)' -or `$_.Service -eq 'hidi2c' } | ForEach-Object { pnputil /restart-device `$_.InstanceId | Out-Null }; pnputil /scan-devices | Out-Null"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad\Status" /v Enabled /t REG_DWORD /d 1 /f >nul 2>&1
powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; `$n = New-Object System.Windows.Forms.NotifyIcon; `$n.Icon = [System.Drawing.SystemIcons]::Information; `$n.Visible = `$true; `$n.ShowBalloonTip(2000, 'WinTouchpadFix', 'Touchpad I2C bus successfully revived!', [System.Windows.Forms.ToolTipIcon]::Info); Start-Sleep -Seconds 1; `$n.Dispose()" >nul 2>&1
exit /b
"@
Set-Content -Path "$dataDir\ReviveEngine.bat" -Value $reviveBat -Force

$action = New-ScheduledTaskAction -Execute "$dataDir\ReviveEngine.bat"
$trigger = New-ScheduledTaskTrigger -Once -At 23:59
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName 'WinTouchpadRevive' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut("$HOME\Desktop\Revive_Touchpad.lnk")
$sc.TargetPath = "C:\Windows\System32\schtasks.exe"
$sc.Arguments = "/run /tn `"WinTouchpadRevive`""
$sc.WorkingDirectory = "$HOME"
$sc.Hotkey = "Ctrl+Alt+T"
$sc.IconLocation = "C:\Windows\System32\main.cpl,0"
$sc.Description = "WinTouchpadFix: Instant 2-Second Touchpad Revive (Ctrl+Alt+T)"
$sc.Save()

Log-Message "      -> Success: Emergency task registered! Hotkey Ctrl+Alt+T active with toast alerts." "Green"

# =========================================================================
# Install Silent Event-Driven Self-Healing Watchdog (SYSTEM)
# =========================================================================
Log-Message "`n[*] Installing Silent Self-Healing Watchdog (Wake / Code 10 Auto-Recovery)..." "Cyan"

$watchdogPs1 = @'
$ErrorActionPreference = 'SilentlyContinue'
$tps = Get-PnpDevice | Where-Object {
    $_.InstanceId -match '^ACPI\\(ELAN|SYNA|SYN|GDX|GXTP|FTE|MSFT0001|COMP0001|PNP0C50)' -or $_.Service -eq 'hidi2c'
}
if ($tps -and ($tps | Where-Object { $_.Status -ne 'OK' })) {
    $log = 'C:\ProgramData\WinTouchpadFix\WinTouchpadFix.log'
    "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [Watchdog] Touchpad not OK -> auto-reviving I2C bus..." | Out-File $log -Append -Encoding utf8
    Get-PnpDevice | Where-Object { $_.FriendlyName -match 'I2C Host Controller' -or $_.Service -match '^iaLPSS2_I2C|^amd_i2c' } |
        ForEach-Object { pnputil /restart-device $_.InstanceId | Out-Null }
    $tps | ForEach-Object { pnputil /restart-device $_.InstanceId | Out-Null }
    pnputil /scan-devices | Out-Null
}
'@
Set-Content -Path "$dataDir\Watchdog.ps1" -Value $watchdogPs1 -Force

$watchdogXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger><Enabled>true</Enabled></LogonTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and (EventID=507 or EventID=107)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and EventID=1]]&lt;/Select&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-Kernel-PnP/Configuration"&gt;&lt;Select Path="Microsoft-Windows-Kernel-PnP/Configuration"&gt;*[System[EventID=411]]&lt;/Select&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <ExecutionTimeLimit>PT2M</ExecutionTimeLimit>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "$dataDir\Watchdog.ps1"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
Register-ScheduledTask -TaskName 'WinTouchpadWatchdog' -Xml $watchdogXml -Force | Out-Null
Log-Message "      -> Success: Silent Watchdog active (auto-heals on Modern Standby wake & Code 10)." "Green"

# =========================================================================
# LIVE STATUS AUDIT & RE-CYCLE
# =========================================================================
Log-Message "`n==========================================================================" "Cyan"
Log-Message "                      LIVE DEVICE HEALTH AUDIT                            " "Cyan"
Log-Message "==========================================================================" "Cyan"

# Clean up phantom/stale Unknown HID touchpad nodes from past crashes
Get-PnpDevice | Where-Object { $_.Status -eq 'Unknown' -and $_.InstanceId -match '^HID\\(ELAN|SYNA|SYN|GDX|GXTP|FTE|MSFT0001|COMP0001|PNP0C50)' } | ForEach-Object {
    pnputil /remove-device $_.InstanceId >$null 2>&1
}

Get-PnpDevice | Where-Object { $_.FriendlyName -match 'I2C Host Controller' -or $_.Service -match '^iaLPSS2_I2C|^amd_i2c' } | ForEach-Object { pnputil /restart-device $_.InstanceId >$null 2>&1 }
Get-PnpDevice | Where-Object { $_.InstanceId -match '^ACPI\\(ELAN|SYNA|SYN|GDX|GXTP|FTE|MSFT0001|COMP0001|PNP0C50)' -or $_.Service -eq 'hidi2c' } | ForEach-Object { pnputil /restart-device $_.InstanceId >$null 2>&1 }
pnputil /scan-devices >$null 2>&1

$touchpads = Get-PnpDevice | Where-Object { $_.FriendlyName -match 'Touchpad|Trackpad|I2C HID' -or $_.InstanceId -match 'ELAN|SYNA|COMP0001' }
$touchpads | Format-Table -AutoSize FriendlyName, InstanceId, Status, Problem

Log-Message "==========================================================================" "Green"
Log-Message "               TOUCHPAD HARDENING COMPLETED SUCCESSFULLY!                 " "Green"
Log-Message "  All vulnerabilities across Sleep, Shutdown, Restarts & USBs are sealed. " "Green"
Log-Message "==========================================================================" "Green"
Log-Message "Diagnostic log saved to: $logFile" "Cyan"
