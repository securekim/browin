#Requires AutoHotkey v2.0
#SingleInstance Force

; win-hotkeys — terminal launcher + virtual desktop window mover
;
;   Win+T           new Windows Terminal on the CURRENT desktop
;   Win+Alt+1..9    move active window to desktop N and follow it
;   Win+Alt+Left    move active window to the previous desktop and follow it
;   Win+Alt+Right   move active window to the next desktop and follow it
;   Win+Alt+Shift+Left/Right   same, but stay on the current desktop
;
; Desktop moving needs VirtualDesktopAccessor.dll next to this script.
; setup.ps1 downloads it. Without the dll, only Win+T works.

global pCount := 0, pCurrent := 0, pGoTo := 0, pMove := 0

InitVDA() {
    global
    dll := A_ScriptDir "\VirtualDesktopAccessor.dll"
    if !FileExist(dll)
        return false
    handle := DllCall("LoadLibrary", "Str", dll, "Ptr")
    if !handle
        return false
    pCount   := DllCall("GetProcAddress", "Ptr", handle, "AStr", "GetDesktopCount", "Ptr")
    pCurrent := DllCall("GetProcAddress", "Ptr", handle, "AStr", "GetCurrentDesktopNumber", "Ptr")
    pGoTo    := DllCall("GetProcAddress", "Ptr", handle, "AStr", "GoToDesktopNumber", "Ptr")
    pMove    := DllCall("GetProcAddress", "Ptr", handle, "AStr", "MoveWindowToDesktopNumber", "Ptr")
    return (pCount && pCurrent && pGoTo && pMove)
}

; n is 0-based: desktop 1 is 0.
MoveActiveTo(n, follow := true) {
    global pCount, pGoTo, pMove
    if !pMove {
        TrayTip "VirtualDesktopAccessor.dll not loaded", "win-hotkeys"
        return
    }
    count := DllCall(pCount, "Int")
    if (n < 0 || n >= count) {
        TrayTip "Desktop " (n + 1) " does not exist (" count " total)", "win-hotkeys"
        return
    }
    hwnd := WinExist("A")
    if !hwnd
        return
    DllCall(pMove, "Ptr", hwnd, "Int", n)
    if follow
        DllCall(pGoTo, "Int", n)
}

MoveActiveBy(delta, follow := true) {
    global pCurrent
    if !pCurrent
        return
    MoveActiveTo(DllCall(pCurrent, "Int") + delta, follow)
}

hasVDA := InitVDA()
TrayTip hasVDA ? "Ready (desktop moving enabled)" : "Ready (Win+T only — dll missing)", "win-hotkeys"

#t::Run "wt.exe"

#!1::MoveActiveTo(0)
#!2::MoveActiveTo(1)
#!3::MoveActiveTo(2)
#!4::MoveActiveTo(3)
#!5::MoveActiveTo(4)
#!6::MoveActiveTo(5)
#!7::MoveActiveTo(6)
#!8::MoveActiveTo(7)
#!9::MoveActiveTo(8)

#!Left::MoveActiveBy(-1)
#!Right::MoveActiveBy(1)
#!+Left::MoveActiveBy(-1, false)
#!+Right::MoveActiveBy(1, false)
