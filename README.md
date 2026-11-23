# WinTouchpadFix

Universal resolution and hardening engine for the common Windows **"I2C HID Device (Code 10: CM_PROB_FAILED_START)"** touchpad failure.

Works across major PC manufacturers (Lenovo, Dell, HP, ASUS, Acer) and touchpad vendors (ELAN, Synaptics, Goodix, FocalTech).

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

## What WinTouchpadFix Does

`WinTouchpadFix` systematically eliminates all failure modes:

* **Disables D3Cold & Enhanced Power Management** directly on the sensor node so operational rail voltage is maintained.
* **Sets `IdleInWorkingState = 0`** across all detected Intel (`VEN_8086`) and AMD (`VEN_1022`) Serial IO I2C host controllers.
* **Extends `DefaultResetTimeout` to 5000ms**, providing 25x more headroom for the hardware handshake.
* **Disables Fast Startup in System Policy**, guaranteeing clean S5 cold boots every time.
* **Prevents Windows Update driver overwriting** via Group Policy.
* **Forces `LeaveOnWithMouse = 1`**, preventing Windows from auto-disabling the touchpad when USB mice or flash drives are plugged in.
* **Registers a 2-second Emergency Reviver** (`Ctrl+Alt+T`) that power-cycles the bus on demand without requiring a system reboot.

---

## How to Use

1. Download or clone this repository.
2. Right-click **`Run_Fix.bat`** and run as Administrator.
3. The script will automatically discover your hardware, apply the protections, and display a live verification table.

---

## Emergency Revive Shortcut

After running the fix, an emergency background task is registered:
* **Hotkey:** `Ctrl` + `Alt` + `T`
* **Desktop Icon:** `Revive_Touchpad`

If the operating system shell ever freezes the cursor, pressing `Ctrl + Alt + T` will instantly power-cycle the I2C host controller and restore touchpad input in 2 seconds.
