#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
Persistent()
SetWorkingDir(A_ScriptDir)

; ---------------------------------------------------------------------------
; Portapapeles typer — host AHK v2
; La UI WebView2 solo publica texto + delay; aqui se escribe con SendInput.
; Wrapper vendored: WebViewToo (github.com/xxxxue/AutoHotKey-WebView2-React)
; WebView2Loader.dll se entrega junto al ejecutable (64 bit).
; ---------------------------------------------------------------------------

#Include vendor\json.ahk
#Include vendor\WebViewToo.ahk

CF_UNICODETEXT := 13
KEYEVENTF_KEYUP := 0x0002
KEYEVENTF_UNICODE := 0x0004
INPUT_KEYBOARD := 1
WM_HOTKEY := 0x0312
MOD_ALT := 0x0001
MOD_CONTROL := 0x0002
MOD_SHIFT := 0x0004
MOD_WIN := 0x0008
HOTKEY_ID := 1

LOCAL_DIR := A_LocalAppData "\ClipboardTyper"
CONFIG_DIR := A_AppData "\ClipboardTyper"
CONFIG_FILE := CONFIG_DIR "\config.json"
SELFTEST_FILE := A_ScriptDir "\selftest.log"
DLL_PATH := LOCAL_DIR "\WebView2Loader.dll"
UI_PATH := LOCAL_DIR "\ui.html"

if !FileExist(LOCAL_DIR)
    DirCreate(LOCAL_DIR)

; --- Config -----------------------------------------------------------------
DefaultConfig() {
    return Map("hotkey", "Ctrl + Shift + V", "delay_ms", 25, "always_on_top", false, "version", 1)
}

LoadConfig() {
    global CONFIG_FILE
    cfg := DefaultConfig()
    if !FileExist(CONFIG_FILE)
        return cfg
    try {
        obj := JSON.parse(FileRead(CONFIG_FILE, "UTF-8"))
        for key, value in cfg {
            if obj.Has(key) && (Type(obj[key]) = Type(value))
                cfg[key] := obj[key]
        }
    } catch {
        return DefaultConfig()
    }
    return cfg
}

SaveConfig(cfg) {
    global CONFIG_DIR, CONFIG_FILE
    if !FileExist(CONFIG_DIR)
        DirCreate(CONFIG_DIR)
    temp := CONFIG_FILE ".tmp"
    FileDelete(temp)
    FileAppend(JSON.stringify(cfg), temp, "UTF-8")
    FileMove(temp, CONFIG_FILE, true)
}

cfg := LoadConfig()

; --- WebView2 ---------------------------------------------------------------
if !FileExist(DLL_PATH) {
    MsgBox("WebView2Loader.dll no encontrado.`nDescarga el WebView2 Evergreen Runtime desde https://developer.microsoft.com/microsoft-edge/webview2/ y vuelve a instalar.", "Portapapeles typer", "IconExclamation")
    ExitApp(1)
}
if !FileExist(UI_PATH) {
    MsgBox("No se encontro ui.html en " LOCAL_DIR, "Portapapeles typer", "IconExclamation")
    ExitApp(1)
}

settings := Map("DllPath", DLL_PATH, "DataDir", LOCAL_DIR "\WebView2Data")
g := WebViewGui("+Resize", , , settings)
g.Title := "Historial del portapapeles"
g.Control.IsWebMessageEnabled := true
g.Control.Navigate("file:///" StrReplace(UI_PATH, "\", "/"))
g.OnMessage(WM_HOTKEY, OnHotkey)
g.Control.WebMessageReceived(OnWebMessage)

; --- Hotkey global ----------------------------------------------------------
HotkeyParts(hk) {
    mods := 0
    parts := StrSplit(hk, " + ")
    base := ""
    for part in parts {
        p := Trim(part)
        if (p = "Ctrl")
            mods |= MOD_CONTROL
        else if (p = "Alt")
            mods |= MOD_ALT
        else if (p = "Shift")
            mods |= MOD_SHIFT
        else if (p = "Win")
            mods |= MOD_WIN
        else if (p != "")
            base := p
    }
    return [mods, base]
}

RegisterMacro(hk) {
    global g
    parts := HotkeyParts(hk)
    if (StrLen(parts[2]) != 1) {
        MsgBox("El hotkey debe terminar en una tecla simple (letra o numero).", "Portapapeles typer", "IconExclamation")
        return false
    }
    vk := Ord(StrUpper(parts[2]))
    DllCall("user32\UnregisterHotKey", "Ptr", g.Hwnd, "Int", HOTKEY_ID)
    ok := DllCall("user32\RegisterHotKey", "Ptr", g.Hwnd, "Int", HOTKEY_ID, "UInt", parts[1], "UInt", vk, "Int")
    if !ok
        MsgBox("El hotkey " hk " esta ocupado por otra aplicacion.`nElige otra combinacion.", "Portapapeles typer", "IconExclamation")
    return ok
}

if !RegisterMacro(cfg["hotkey"])
    cfg["hotkey"] := "Ctrl + Shift + V"

if cfg["always_on_top"]
    WinSetAlwaysOnTop true, "ahk_id " g.Hwnd

; --- Escritura --------------------------------------------------------------
SendUnicodeChar(ch) {
    global KEYEVENTF_KEYUP, KEYEVENTF_UNICODE, INPUT_KEYBOARD
    cb := DllCall("user32\SendInput", "UInt", 1, "Ptr", BuildInput(ch, 0), "Int", 40)
    DllCall("user32\SendInput", "UInt", 1, "Ptr", BuildInput(ch, KEYEVENTF_KEYUP), "Int", 40)
    return cb
}

BuildInput(ch, flags) {
    global KEYEVENTF_UNICODE, INPUT_KEYBOARD
    buf := BufferAlloc(40, 0)
    NumPut("UInt", INPUT_KEYBOARD, buf, 0)
    NumPut("UShort", 0, buf, 8)
    NumPut("UShort", Ord(ch), buf, 10)
    NumPut("UInt", KEYEVENTF_UNICODE | flags, buf, 12)
    return buf
}

TypeText() {
    global g, cfg
    rawText := g.Control.ExecuteScript("typerState.getText()")
    rawDelay := g.Control.ExecuteScript("typerState.getDelay()")
    try {
        text := JSON.parse(rawText)
        delay := JSON.parse(rawDelay)
    } catch {
        return
    }
    if !text
        return
    if !IsNumber(delay)
        delay := 25
    delay := Min(100, Max(5, delay))
    for ch in StrSplit(text) {
        SendUnicodeChar(ch)
        Sleep(delay)
    }
}

OnHotkey(wParam, lParam, msg, hwnd) {
    if (wParam = HOTKEY_ID)
        TypeText()
}

; --- Portapapeles -> historial ----------------------------------------------
OnClipboardChange(ClipChanged)
ClipChanged(type) {
    global g
    if (!DllCall("user32\IsClipboardFormatAvailable", "UInt", CF_UNICODETEXT, "Int")) {
        return
    }
    text := A_Clipboard
    if !text
        return
    js := "typerState.addClipboardText(" JSON.stringify(text) ")"
    g.Control.ExecuteScriptAsync(js)
}

; --- Mensajes de la UI ------------------------------------------------------
OnWebMessage(w, e) {
    global cfg, g
    try {
        payload := JSON.parse(JSON.parse(e.WebMessageAsJson))
    } catch {
        return
    }
    switch payload["type"] {
        case "always_on_top":
            WinSetAlwaysOnTop !!payload["value"], "ahk_id " g.Hwnd
            cfg["always_on_top"] := !!payload["value"]
            SaveConfig(cfg)
        case "delay_ms":
            cfg["delay_ms"] := Min(100, Max(5, payload["value"]))
            SaveConfig(cfg)
        case "hotkey":
            newHk := payload["value"]
            if RegisterMacro(newHk) {
                cfg["hotkey"] := newHk
                SaveConfig(cfg)
            } else {
                g.Control.ExecuteScriptAsync("typerState.resetHotkey()")
            }
        case "clear_history":
            SaveConfig(cfg)
    }
}

; --- Bandeja ----------------------------------------------------------------
panelVisible := false

TogglePanel() {
    global g, panelVisible
    panelVisible := !panelVisible
    if panelVisible
        g.Show("w460 h720 Center")
    else
        g.Hide()
}
A_TrayMenu.Add("Mostrar/Ocultar", (*) => TogglePanel())
A_TrayMenu.Add("Salir", (*) => ExitApp())

; --- Self test --------------------------------------------------------------
WriteSelfTest() {
    global DLL_PATH, UI_PATH, CONFIG_FILE, cfg
    lines := []
    lines.Push("webview2=" (FileExist(DLL_PATH) ? "OK" : "FAIL: falta WebView2Loader.dll"))
    lines.Push("hotkey=" (RegisterMacro(cfg["hotkey"]) ? "OK" : "FAIL: ocupado"))
    lines.Push("clipboard=" (DllCall("user32\IsClipboardFormatAvailable", "UInt", CF_UNICODETEXT, "Int") ? "OK" : "FAIL: sin texto"))
    lines.Push("sendinput=" (A_PtrSize = 8 ? "OK" : "FAIL: requiere x64"))
    lines.Push("config=" (FileExist(CONFIG_FILE) ? "OK" : "FAIL: sin config"))
    lines.Push("ui=" (FileExist(UI_PATH) ? "OK" : "FAIL: falta ui.html"))
    FileDelete(SELFTEST_FILE)
    for line in lines
        FileAppend(line "`n", SELFTEST_FILE, "UTF-8")
}

if A_Args.Has(1) && (A_Args[1] = "--self-test") {
    WriteSelfTest()
    ExitApp(0)
}

g.Show("w460 h720 Center")
panelVisible := true
