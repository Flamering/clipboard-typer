# Portapapeles typer (Windows 11)

Panel de historial del portapapeles estilo Win+V que **escribe** el texto elegido letra por letra en el campo con el foco, en lugar de pegarlo.

## Instalación en tu PC Windows

### Forma rápida (un comando)

1. Copia esta carpeta del proyecto a tu PC (por ejemplo con `scp -r /root/clipboard-typer usuario@TU-PC:C:\clipboard-typer` o por USB).
2. Instala **AutoHotkey v2 (64-bit)** desde <https://www.autohotkey.com/> — hace falta para compilar.
3. Abre PowerShell en la carpeta copiada y ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1
```

El script descarga `WebView2Loader.dll`, compila `src\ClipboardTyper.ahk` con Ahk2Exe y deja todo en `%LOCALAPPDATA%\ClipboardTyper`. Luego ejecuta:

```powershell
& "$env:LOCALAPPDATA\ClipboardTyper\ClipboardTyper.exe" --self-test
Get-Content "$env:LOCALAPPDATA\ClipboardTyper\selftest.log"
```

### Si Windows muestra "Windows protegió tu PC"

Pulsa **Más información → Ejecutar de todos modos**. El binario de v1 no está firmado (deuda en el spec).

### Instalación manual (sin Ahk2Exe)

Copia a `%LOCALAPPDATA%\ClipboardTyper\` estos cuatro ficheros: `src\ClipboardTyper.ahk` (renombrado a `ClipboardTyper.exe`), `src\ui.html`, `src\bridge.testable.js` y `WebView2Loader.dll` x64. Instala AutoHotkey v2 y ejecuta el `.ahk` con él. Funciona, pero requiere tener AHK instalado.

No necesita administrador, no instala servicios y no escribe en `Program Files`.

Si falta el runtime WebView2 (Windows 10 o Windows 11 recortado), el programa muestra un aviso con el enlace al *WebView2 Evergreen Runtime*.

> **Build desde Linux:** el `.exe` del zip generado aquí es un *placeholder* (es el `.ahk` copiado). El script `install-windows.ps1` lo compila correctamente en Windows.

## Uso

- Copia texto como siempre: aparece como primera tarjeta del historial (máximo 25 entradas, scroll interno).
- Haz clic en la tarjeta que quieras escribir.
- **Hotkey por defecto:** `Ctrl + Shift + V` → escribe ese texto en el campo con el foco, carácter por carácter.
- **Velocidad:** slider de 5 a 100 ms por letra (`rápido` ≤ 15, `normal` ≤ 40, `lento` > 40). El cambio se aplica en el siguiente disparo, sin reiniciar.
- **Chincheta:** alterna "siempre encima"; el estado se guarda.
- **Activación:** pulsa el botón `Ctrl + Shift + V`, luego tus teclas (modificadores + tecla simple). `Esc` cancela. Si el combo está ocupado, se muestra un aviso y se conserva el anterior.
- **Borrar todo:** vacía el historial; no borra velocidad, pin ni hotkey.

Acentos y `ñ` se escriben correctamente mediante `KEYEVENTF_UNICODE`. Emojis fuera del BMP pueden no escribirse bien en v1.

## Desinstalación

Cierra el programa y borra:

- la carpeta donde descomprimiste el zip,
- `%LOCALAPPDATA%\ClipboardTyper\` (ui.html, DLL y datos del navegador),
- `%APPDATA%\ClipboardTyper\` (config.json).

No hay desinstalador ni entradas de inicio automático.

## Límites conocidos

- Windows x64. En ARM64 corre emulado.
- No funciona en campos de escritorio seguro ni en aplicaciones elevadas.
- Sin red, sin telemetría, sin sincronización en la nube.
- V1 no garantiza comportamiento frente a mecanismos anti-automatización de sitios terceros.

## Desarrollo y verificación

```bash
node --test tests/
node scripts/validate-ui.js
bash scripts/package.sh
bash scripts/clean.sh
```

En Windows, ejecuta `ClipboardTyper.exe --self-test` y revisa `selftest.log`; la checklist de campo está en `docs/superpowers/evidence/`.

## Origen de dependencias vendored

`src/vendor/` contiene el wrapper WebViewToo y sus dependencias, tomados de
`github.com/xxxxue/AutoHotKey-WebView2-React` (ruta `src-runtime/ahk-lib/`).
`WebView2Loader.dll` se descarga del paquete NuGet oficial `Microsoft.Web.WebView2`
en cada empaquetado. Revisa las licencias de esos proyectos antes de redistribuir.
