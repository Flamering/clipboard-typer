# Avisos de terceros

Este proyecto incluye o descarga componentes de terceros. Sus condiciones se detallan abajo.

## 1. Wrapper WebView2 para AutoHotkey (`src/vendor/`)

Archivos: `WebView2.ahk`, `WebViewToo.ahk`, `ComVar.ahk`, `Promise.ahk`, `json.ahk`.

- Origen: <https://github.com/xxxxue/AutoHotKey-WebView2-React>, ruta `src-runtime/ahk-lib/`.
- **Estado de licencia: el repositorio upstream NO declara licencia.**

Eso significa que no hay una licencia explícita que autorice su redistribución. Antes de distribuir este proyecto públicamente de forma amplia, se recomienda sustituirlo por una alternativa con licencia clara, por ejemplo:

- <https://github.com/G33kDude/WebView2.ahk> — **MIT**, expone `ExecuteScriptAsync`, `add_WebMessageReceived` y `PostWebMessageAsJson`, e incluye `WebView2Loader.dll` x64.

El cambio requiere adaptar `src/ClipboardTyper.ahk` (el wrapper actual aporta una clase `WebViewGui` de alto nivel). Queda registrado como decisión pendiente del propietario.

## 2. Microsoft WebView2 Runtime / WebView2Loader.dll

- El instalador descarga `WebView2Loader.dll` x64 desde el paquete NuGet oficial `Microsoft.Web.WebView2` (versión fijada en `scripts/install-windows.ps1`).
- El Runtime se instala desde el bootstrapper oficial de Microsoft o desde winget.
- Condiciones: <https://www.microsoft.com/web/webpi/eula/net_library_eula_enu.htm> y la documentación de redistribución de WebView2.
- Microsoft no es propietario del código de este repositorio.

## 3. AutoHotkey v2

- El instalador instala AutoHotkey v2 desde winget o desde los binarios oficiales de <https://github.com/AutoHotkey/AutoHotkey>.
- AutoHotkey se distribuye bajo su propia licencia (GPL v2 con excepciones; consulta <https://www.autohotkey.com/license/>).
- Este repositorio no redistribuye el instalador de AutoHotkey: solo lo descarga en tiempo de instalación.

## 4. Dependencias de desarrollo

- Node.js y Python 3 se usan solo para tests y empaquetado en el entorno de desarrollo; no se incluyen en el producto.
