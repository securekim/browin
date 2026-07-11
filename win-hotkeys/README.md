# win-hotkeys

Two things Windows does not give you:

- a terminal that opens on the desktop **you are actually looking at**
- a keyboard shortcut to **move a window to another virtual desktop**

`Win+Shift+Arrow` only moves windows between *monitors*. `Win+Ctrl+Arrow` switches
desktops but leaves the window behind. Moving a window across desktops is
mouse-only (Task View drag), and PowerToys does not cover it either.

## Hotkeys

| Key | Action |
| --- | --- |
| `Win+T` | new Windows Terminal on the current desktop |
| `Win+Alt+1` … `Win+Alt+9` | move the active window to desktop N, and follow it |
| `Win+Alt+Left` / `Win+Alt+Right` | move the active window to the adjacent desktop, and follow it |
| `Win+Alt+Shift+Left` / `Win+Alt+Shift+Right` | move it, but stay on the current desktop |

Edit the hotkey lines at the bottom of `win-hotkeys.ahk` to remap them.

## Install

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

That installs AutoHotkey v2 (winget), downloads `VirtualDesktopAccessor.dll` next
to the script, adds a shortcut to your Startup folder so the hotkeys survive a
reboot, and starts it. Re-running is safe.

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -NoStartup   # do not run at logon
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -Uninstall   # stop it, drop the Startup shortcut
```

## Why the DLL

Windows has no public API for virtual desktops. Desktop moving goes through
[VirtualDesktopAccessor](https://github.com/Ciantic/VirtualDesktopAccessor),
which talks to the undocumented COM interface. That interface is **tied to the
Windows build** — after a big Windows upgrade the DLL may need updating before
desktop moving works again. `Win+T` does not depend on it.

The DLL is downloaded by `setup.ps1` and is not committed here.

Verified on Windows 11 build 26200 with VirtualDesktopAccessor `2024-12-16-windows11`.

## Bonus: Win+R opening on the wrong desktop

Typing `cmd` into Win+R can yank you to another desktop. The Run dialog is a
single Explorer-owned window that gets reused, so it reappears on whichever
desktop it was last created on, and Windows switches you there to show it.
`Win+T` sidesteps the Run dialog entirely, which is the real fix.

If you want the terminal itself to always open a fresh window, set this in
Windows Terminal's `settings.json`:

```json
"windowingBehavior": "useNew"
```
