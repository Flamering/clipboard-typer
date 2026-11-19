# Portapapeles typer

Panel de historial del portapapeles estilo **Windows 11** que **escribe** el texto elegido letra por letra en el campo con el foco, en lugar de pegarlo. Útil cuando un formulario ignora `Ctrl+V` o cuando necesitas controlar la velocidad de entrada.

- Historial de los últimos 25 textos copiados, con scroll interno vertical.
- Slider de **5 a 100 ms por letra** (rápido / normal / lento), aplicable en caliente.
- Hotkey global configurable desde la propia GUI (por defecto `Ctrl+Shift+V`).
- Botón de anclaje "siempre encima" con estado persistente.
- Bandeja del sistema para mostrar/ocultar el panel.
- Escritura con `SendInput` + `KEYEVENTF_UNICODE` (acentos y `ñ` correctos).
- Instalación por usuario, sin administrador, sin servicios, sin red en tiempo de ejecución.

## Descarga e instalación

### Desde GitHub (recomendado)

1. En la página de **Releases**, descarga `clipboard-typer-instalador-v1.0.0.zip`.
2. Descomprime en cualquier carpeta de tu usuario.
3. Abre PowerShell dentro de la carpeta descomprimida y ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1
```

O, si has clonado el repositorio:

```bash
git clone https://github.com/Flamering/clipboard-typer.git
cd clipboard-typer
```

y el mismo comando PowerShell.

### Qué instala el instalador

El script `scripts/install-windows.ps1` es **completo**:

1. Instala **WebView2 Runtime** (winget; si no está, bootstrapper oficial de Microsoft).
2. Instala **AutoHotkey v2 de 64 bit** (winget; si no, descarga el último setup de GitHub con `/SILENT`).
3. Descarga `WebView2Loader.dll` x64 del paquete NuGet oficial `Microsoft.Web.WebView2`.
4. Compila `src\ClipboardTyper.ahk` con **Ahk2Exe**.
5. Copia el programa y sus recursos a `%LOCALAPPDATA%\ClipboardTyper\`.
6. Crea accesos directos en Inicio y Escritorio.
7. Registra **Portapapeles typer** en *Aplicaciones y características* para poder desinstalarlo.

No pide administrador y no escribe en `Program Files`. El progreso se guarda en `%TEMP%\clipboard-typer-install.log`.

Opciones:

| Opción | Efecto |
|---|---|
| `-SkipDependencies` | No instala AutoHotkey ni WebView2 (útil si ya los tienes o estás sin red). |
| `-NoDesktopShortcut` | No crea el acceso del Escritorio. |
| `-NoAutoStart` | Reservado; v1 no crea inicio automático de todos modos. |
| `-Ahk2Exe "ruta"` | Ruta explícita a `Ahk2Exe.exe`. |
| `-InstallDir "ruta"` | Directorio de destino distinto. |

Si Windows muestra *"Windows protegió tu PC"*, pulsa **Más información → Ejecutar de todos modos** (el binario de v1 no está firmado; ver deuda en el spec).

## Verificación

```powershell
& "$env:LOCALAPPDATA\ClipboardTyper\ClipboardTyper.exe" --self-test
Get-Content "$env:LOCALAPPDATA\ClipboardTyper\selftest.log"
```

Esperado: `webview2=OK`, `hotkey=OK`, `clipboard=OK`, `sendinput=OK`, `config=OK`, `ui=OK`.

La checklist completa de campo está en
`docs/superpowers/evidence/2026-11-19-clipboard-typer-field-checklist.md`.
El spec no se marca `VERIFICADO` hasta que esa checklist y el `selftest.log` estén completos en el equipo Windows.

## Uso

1. Copia texto como siempre: aparece como primera tarjeta del historial.
2. Haz clic en la tarjeta que quieras escribir.
3. Pon el foco en el campo del formulario y pulsa `Ctrl+Shift+V` (o tu hotkey).
4. El texto se escribe carácter por carácter al delay del slider.

- **Velocidad:** 5–100 ms/letra. El cambio se aplica en el siguiente disparo, sin reiniciar.
- **Chincheta:** alterna "siempre encima"; se guarda en la config.
- **Activación:** pulsa el botón del hotkey, luego modificadores + tecla simple. `Esc` cancela. Si el combo está ocupado, aparece un aviso y se conserva el anterior.
- **Borrar todo:** vacía el historial; no toca velocidad, pin ni hotkey.
- **Bandeja:** clic derecho → *Mostrar/Ocultar* o *Salir*.

## Desinstalación

Desde *Aplicaciones y características* → **Portapapeles typer** → Desinstalar, o:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ClipboardTyper\uninstall-windows.ps1"
```

Borra accesos directos, entrada de registro, el programa y su configuración. Añade `-KeepConfig` para conservar velocidad, pin y hotkey.

## Arquitectura

```
Portapapeles Win32
  → OnClipboardChange (AHK) → historial ≤25
  → WebView2 (ui.html + bridge.testable.js) → selección + delay + hotkey
  → window.typerState (puente JS↔AHK)
  → RegisterHotKey global → SendInput carácter por carácter → campo con foco
```

La GUI **nunca** genera eventos de teclado: solo publica `{texto, delay}`. Eso evita el problema de los eventos sintéticos con `isTrusted=false`, que los formularios que bloquean el pegado suelen ignorar.

| Pieza | Archivo | Responsabilidad |
|---|---|---|
| Lógica pura | `src/bridge.testable.js` | hotkey, delay, config, historial — testeable en Node |
| UI | `src/ui.html` | panel, scroll, slider, pin, editor de hotkey |
| Host | `src/ClipboardTyper.ahk` | clipboard, hotkey, always-on-top, `SendInput`, self-test |
| Wrapper WebView2 | `src/vendor/` | puente COM con Edge WebView2 |
| Instalador | `scripts/install-windows.ps1` | dependencias + compilación + registro |
| Desinstalador | `scripts/uninstall-windows.ps1` | limpieza completa |

## Desarrollo y tests

Requiere Node 18+ y Python 3 (para generar el zip).

```bash
npm test                       # 10 tests: lógica, UI, AHK estático, empaquetado, instaladores
node scripts/validate-ui.js    # valida el HTML del panel
bash scripts/package.sh        # genera dist/ClipboardTyper-v1.0.0.zip
bash scripts/clean.sh          # borra dist/ y build/
```

Para generar el **zip del instalador** (el que se sube a Releases):

```bash
python3 -c "import shutil; shutil.make_archive('clipboard-typer-instalador-v1.0.0','zip','clipboard-typer')"
```

Los tests de AHK, instalador y empaquetado son **estáticos**: este repositorio se desarrolla en Linux y no puede ejecutar Windows, AHK ni PowerShell. La parte dinámica se comprueba con `--self-test` y la checklist de campo.

## Limitaciones

- Windows 11 x64. En ARM64 corre emulado.
- Emojis fuera del BMP (supervolados) pueden no escribirse bien en v1.
- No funciona en campos de escritorio seguro ni en aplicaciones elevadas.
- Sin red, telemetría ni sincronización en la nube.
- V1 no promete comportamiento frente a mecanismos anti-automatización de sitios terceros.
- El `.exe` generado fuera de Windows es un placeholder; el instalador lo compila con Ahk2Exe en el equipo destino.

## Documentación del diseño

- Spec: `docs/superpowers/specs/2026-11-19-clipboard-typer-design.md`
- Plan: `docs/superpowers/plans/2026-11-19-clipboard-typer.md`
- Estado: `docs/superpowers/INDEX.md`
- Avisos de terceros: `THIRD_PARTY_NOTICES.md`

## Licencia

MIT para el código propio de este repositorio (ver `LICENSE`). El código incluido en `src/vendor/` y el DLL de Microsoft tienen sus propias condiciones: consulta `THIRD_PARTY_NOTICES.md`.
