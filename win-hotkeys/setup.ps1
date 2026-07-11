<#
    win-hotkeys setup — run once per machine.

        powershell -ExecutionPolicy Bypass -File .\setup.ps1

    What it does:
      1. installs AutoHotkey v2 via winget (skipped if already present)
      2. downloads VirtualDesktopAccessor.dll from its GitHub release into this folder
      3. adds a shortcut to the user's Startup folder so the hotkeys come back after a reboot
      4. starts the hotkey script now

    Safe to re-run. Nothing here runs elevated and nothing is written outside
    this folder and the user's own Startup folder.

    Options:
      -NoStartup   skip step 3 (hotkeys will not survive a reboot)
      -Uninstall   remove the Startup shortcut and stop the script
#>
[CmdletBinding()]
param(
    [switch]$NoStartup,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ahkScript   = Join-Path $scriptDir 'win-hotkeys.ahk'
$dllPath     = Join-Path $scriptDir 'VirtualDesktopAccessor.dll'
$startupLink = Join-Path ([Environment]::GetFolderPath('Startup')) 'win-hotkeys.lnk'

function Stop-Hotkeys {
    Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*win-hotkeys.ahk*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Find-AutoHotkey {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey64.exe'),
        (Join-Path $env:ProgramFiles  'AutoHotkey\v2\AutoHotkey64.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey\v2\AutoHotkey32.exe'),
        (Join-Path $env:ProgramFiles  'AutoHotkey\v2\AutoHotkey32.exe')
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

if ($Uninstall) {
    Stop-Hotkeys
    if (Test-Path $startupLink) { Remove-Item $startupLink -Force }
    Write-Host 'win-hotkeys stopped and removed from Startup. AutoHotkey itself was left installed.'
    return
}

# --- 1. AutoHotkey v2 ---------------------------------------------------------
$ahk = Find-AutoHotkey
if (-not $ahk) {
    Write-Host 'Installing AutoHotkey v2 ...'
    winget install --id AutoHotkey.AutoHotkey --source winget `
        --accept-package-agreements --accept-source-agreements --silent | Out-Null
    $ahk = Find-AutoHotkey
}
if (-not $ahk) { throw 'AutoHotkey v2 not found after install. Install it manually, then re-run.' }
Write-Host "AutoHotkey : $ahk"

# --- 2. VirtualDesktopAccessor.dll -------------------------------------------
# github.com/Ciantic/VirtualDesktopAccessor — wraps the undocumented COM API
# Windows uses for virtual desktops. It is tied to the Windows build, so a major
# Windows upgrade can break desktop moving until the DLL is updated. Win+T keeps
# working either way.
if (Test-Path $dllPath) {
    Write-Host "VDA dll    : already present"
} else {
    Write-Host 'Downloading VirtualDesktopAccessor.dll ...'
    $headers = @{ 'User-Agent' = 'win-hotkeys-setup' }
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/Ciantic/VirtualDesktopAccessor/releases/latest' -Headers $headers
    $asset   = $release.assets | Where-Object { $_.name -eq 'VirtualDesktopAccessor.dll' } | Select-Object -First 1
    if (-not $asset) { throw 'VirtualDesktopAccessor.dll is not in the latest release.' }
    Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $dllPath
    Write-Host "VDA dll    : $($release.tag_name)"
}

# --- 3. come back after a reboot ---------------------------------------------
if ($NoStartup) {
    Write-Host 'Startup    : skipped (-NoStartup)'
} else {
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($startupLink)
    $lnk.TargetPath       = $ahk
    $lnk.Arguments        = "`"$ahkScript`""
    $lnk.WorkingDirectory = $scriptDir
    $lnk.Description      = 'win-hotkeys: terminal + virtual desktop hotkeys'
    $lnk.Save()
    Write-Host "Startup    : $startupLink"
}

# --- 4. (re)start -------------------------------------------------------------
Stop-Hotkeys
Start-Process -FilePath $ahk -ArgumentList "`"$ahkScript`"" -WorkingDirectory $scriptDir

Write-Host ''
Write-Host 'win-hotkeys is running:'
Write-Host '  Win+T                      new Windows Terminal on the current desktop'
Write-Host '  Win+Alt+1..9               move the active window to desktop N and follow it'
Write-Host '  Win+Alt+Left/Right         move it to the adjacent desktop and follow it'
Write-Host '  Win+Alt+Shift+Left/Right   move it, but stay where you are'
