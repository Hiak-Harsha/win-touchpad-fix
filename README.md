# WinTouchpadFix

Universal resolution and hardening engine for the common Windows **"I2C HID Device (Code 10: CM_PROB_FAILED_START)"** touchpad failure.

Works across major PC manufacturers (Lenovo, Dell, HP, ASUS, Acer) and touchpad vendors (ELAN, Synaptics, Goodix, FocalTech) on both Intel and AMD platforms.

---

## Quick Install (One-Liner)

Open PowerShell as Administrator and run:

```powershell
irm https://raw.githubusercontent.com/Hiak-Harsha/win-touchpad-fix/main/install.ps1 | iex
```

---

## The Problem Explained

On modern Windows laptops, touchpads connect via an internal **I2C Serial IO bus** rather than legacy PS/2 or USB ports. Under Windows 10 and 11, five architectural design decisions frequently collide to produce persistent touchpad dropouts:

1. **Modern Standby & D3Cold Power Cut:**  
   Windows puts the touchpad sensor into a deep `D3Cold` sleep state during idle or lid closure. When waking up, the sensor chip cannot charge its internal capacitors and reply before Windows gives up.
2. **Aggressive I2C Host Bus Idle:**  
   The motherboard Intel/AMD Serial IO Host Controller powers down its bus clock after brief pauses (`IdleInWorkingState = 1`).
3. **The 200ms Timeout Crash:**  
   The default `hidi2c.sys` timeout is around 200 milliseconds. When the sensor fails to answer within that window, Windows flags the device with **Code 10** (`CM_PROB_FAILED_START`) and halts communication.
4. **Fast Startup Cache Poisoning:**  
   When Fast Startup (`Hiberboot`) is active, Windows saves the kernel state—including the broken Code 10 error—to disk on shutdown and reloads the broken state upon booting up.
5. **Driver Overwrite Cycling:**  
   Cumulative Windows updates often overwrite patched parameters with generic default configurations.

---

## Features & Capabilities

* **Hardware & Policy Audit (`Audit_Only.bat` / `-AuditOnly`):**  
  Non-destructive inspection that checks if your laptop is currently vulnerable to sleep freezes and Code 10 crashes.
* **System Restore Point Safety Net:**  
  Automatically creates a Windows System Restore point before applying changes.
* **Bus & Sensor Hardening:**  
  Disables D3Cold sleep and forces `IdleInWorkingState = 0` across all Intel (`VEN_8086`) and AMD (`VEN_1022`) host controllers.
* **5000ms Wake Headroom:**  
  Extends `DefaultResetTimeout` to 5000ms (25x more time to handshake on wake).
* **Boot Freeze Immunity:**  
  Disables Fast Startup in system policies to prevent cached error reloading.
* **Windows Update Driver Shield:**  
  Protects functional hardware drivers from being overwritten by cumulative updates.
* **USB & Mouse Coexistence:**  
  Locks `LeaveOnWithMouse = 1` so connecting USB mice or drives never disables the touchpad.
* **Emergency 2-Second Reviver (`Ctrl + Alt + T`):**  
  Registered background task with native Windows toast notification to power-cycle the I2C bus in 2 seconds without restarting.
* **One-Click Factory Revert (`Revert_Fix.bat` / `-Revert`):**  
  Allows instant restoration of original Windows default settings at any time.

---

## Available Scripts

| File | Description |
| :--- | :--- |
| **`Run_Fix.bat`** | Applies all hardening rules and registers the emergency revive task. |
| **`Audit_Only.bat`** | Inspects your system and outputs a vulnerability scorecard without making changes. |
| **`Revert_Fix.bat`** | Restores default Windows power management settings. |
| **`Instant_Revive.bat`** | Standalone script that power-cycles the bus and shows a desktop notification. |
| **`install.ps1`** | Remote installer script for one-line web installation. |

---

## Emergency Revive Shortcut

After running the fix, an emergency background task is registered:
* **Hotkey:** `Ctrl` + `Alt` + `T`
* **Desktop Icon:** `Revive_Touchpad`

If the operating system shell ever freezes the cursor, pressing `Ctrl + Alt + T` will instantly power-cycle the I2C host controller, revive the touchpad in 2 seconds, and display a confirmation notification.
