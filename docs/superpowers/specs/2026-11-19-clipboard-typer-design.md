# Spec de detalle — `2026-11-19-clipboard-typer-design.md`

> Plantilla canónica (`docs/superpowers/templates/spec.md`). Las secciones fijas
> son obligatorias; si una no aplica, escribir `N/A (motivo)` en vez de borrarla.

- **Fecha:** `2026-11-19`
- **Autor:** agente (con Arath como dueño del producto)
- **Estado:** `APROBADO` (Gate A pasado por Arath el 2026-11-19)
- **Ámbito:** aplicación de escritorio Windows 11 (x64). Sin LXCs, sin servicios, sin red. Ficheros nuevos bajo el proyecto `clipboard-typer/`.
- **Supera/relaciona:** ninguna spec previa. Prosigue el prototipo de UI aprobado en esta sesión (panel estilo Win+V con slider, anclaje y hotkey configurable).
- **Precede a:** `docs/superpowers/plans/2026-11-19-clipboard-typer.md`

**Vocabulario de estados (cerrado, en orden):**
`BORRADOR → PROPUESTA → APROBADO → EN EJECUCIÓN → IMPLEMENTADO → VERIFICADO`.
Ningún otro valor es válido. El avance de estado lo registra `INDEX.md`.

---

## 1. Contexto y problema

Arath debe rellenar 79 formularios × 4 campos (316 entradas) en una página web.Ya existen 316 valores que quiere introducer copiándolos al portapapeles, pero pegar (`Ctrl+V`) no sirve: o el formulario ignora el pegado, o quiere el efecto de escritura letra por letra. El portapapeles de Windows 11 ofrece historial (`Win+V`) pero solo pega, no escribe.

La herramienta deseada es un clon visual y funcional de ese panel: copias un texto, aparece en el historial, eliges un elemento, y un hotkey lo escribe carácter por carácter en el campo con el foco, a una velocidad regulable con un slider. Debe poder anclarse siempre encima y permitir cambiar el hotkey desde la propia GUI.

Restricción de entorno: el desarrollo ocurre en un host Linux (homelab) sin Windows y sin acceso al dispositivo de destino. No habrá prueba en campo aquí. Eso condiciona la arquitectura de verificación (§7 y §13): toda la lógica verificable debe poder ejecutarse en Linux, y lo que solo existe en Windows debe entregarse como un autotest y una checklist que ejecuta el usuario.

## 2. Punto de partida verificado (fecha, medición viva)

Medido el 2026-11-19 en el entorno de desarrollo:

| Hecho | Evidencia (comando) |
|---|---|
| Entorno de build es Linux, no Windows | `uname -s` → `Linux` |
| Node disponible para tests de lógica pura | `node --version` → `v22.22.2` |
| AutoHotkey NO ejecutable aquí | `command -v AutoHotkey64.exe` → `AHK: ausente (entorno Linux)` |
| Plantilla canónica de spec disponible | `test -f /mnt/homelab/projects/proxmox/docs/superpowers/templates/spec.md && echo OK` → `template canónico: OK` |
| Proyecto aún no creado | `test -d /root/clipboard-typer` → `proyecto: no existe` |
| UI aprobada visualmente en la sesión | mockup renderizado con scroll interno, slider 5–100 ms, pin y editor de hotkey (artefacto de la conversación, no reproducible por comando) |

Supuestos **no medidos** (declarados, no afirmados como hechos): Windows 11 21H2 o superior incluye el runtime WebView2 Evergreen; el dispositivo de destino permite ejecutar binarios sin firma de código; la sesión de usuario es interactiva y no elevada.

## 3. Objetivos

1. **G1** — Copiar texto en Windows añade el valor al historial del panel (máx. 25 entradas, ACL motivado en §5).
2. **G2** — Seleccionar una entrada del historial (con scroll interno vertical) y pulsar el hotkey escribe ese texto letra por letra en el control con el foco, mediante `SendInput` de Windows.
3. **G3** — Slider de 5 a 100 ms por carácter, con feedback `rápido / normal / lento`, aplicable en caliente sin reiniciar.
4. **G4** — Botón de anclaje tipo toggle que fija el panel siempre encima; estado visible (borde azul) y persistente.
5. **G5** — El hotkey se redefine desde la GUI capturando modificadores + tecla, con `Esc` para cancelar; configuración persistente.
6. **G6** — Instalación en Windows en menos de 2 minutos: un `.zip` con un `.exe` portable, sin administrador, sin asistente, sin escribir en `Program Files`.
7. **G7** — Separar la verificación en una parte ejecutable hoy en Linux y una checklist de campo explícita para el dispositivo Windows (§13).
8. **G8** — La GUI nunca genera eventos de teclado: solo entrega `{texto, delay}`; la escritura ocurre exclusivamente en el host AHK.

## 4. No-objetivos (YAGNI)

- **No pegar.** `Ctrl+V` no se usa en el flujo; el hotkey escribe. Motivo: es el problema original.
- **No imágenes, ni HTML enriquecido, ni OCR.** Motivo: el historial es solo texto plano.
- **No sincronización en la nube ni telemetría.** Motivo: el tool es local y el entorno no tiene red de salida; evita superficie de privacidad.
- **No integración con el homelab.** Motivo: no es una utilidad de homelab (declarado por Arath); no se registra en `INDEX.md` de servicios ni se despliega en LXC.
- **No autocompletado ni mapeo campo→valor en v1.** Motivo: el flujo es copiar → elegir → escribir; el CSV es un posible futuro, no parte de este spec.
- **No autoarranque al iniciar sesión en v1.** Motivo: añade una entrada de registro y fricción de permisos sin beneficio para 316 campos puntuales.
- **No actualización automática.** Motivo: sustituir el `.exe` desde GitHub Releases es suficiente y evita un servicio/endpoint.
- **No garantizar indetectabilidad frente a mecanismos anti-automatización de sitios terceros.** Motivo: el alcance es productividad sobre formularios propios o de uso legítimo.

## 5. Diseño

### 5.1 Alternativas consideradas y decisión

| Alternativa | Por qué se descarta / se elige |
|---|---|
| AHK v2 con GUI nativa (`Gui`, `AddSlider`) | Descartada: aspecto Win32 clásico (parece Win10), sin acrylic ni esquinas redondeadas. Es la de menos dependencias, pero no reproduce la imagen aprobada. |
| **AHK v2 + WebView2 (HTML/CSS local)** | **Elegida.** Reproduce el look Win11 de la captura, mantiene `SendInput` confiable y AHK sigue siendo el único proceso residente. WebView2 viene en Win11. |
| Python + WebView2 + AHK | Descartada para v1: dos procesos vivos, empaquetado de 40–80 MB y un puente HTTP. Se reevaluaría solo si llega el CSV complejo. |
| WinUI 3 / WPF (C#) | Descartada: pixel-perfect pero excesivo para una herramienta de 316 campos; curva y tiempo de build altos. |
| Extensión de Chrome | Descartada en sesiones previas: eventos sintéticos con `isTrusted=false`; formularios que ignoran el pegado suelen ignorarlos también. |

### 5.2 Arquitectura

```
Portapapeles Win32
   │  OnClipboardChange (AHK)
   ▼
Historial en memoria (≤25 textos)
   │  inyecta en la UI vía ExecuteScriptAsync
   ▼
UI WebView2 (ui.html embebido, sin red)
   │  selección + slider + pin + hotkey → window.typerState
   ▼
Puente JS↔AHK (postMessage / ExecuteScriptAsync)
   │
   ▼
Host AHK v2 (residente)
   ├─ RegisterHotKey(global, configurable)
   ├─ SendInput carácter por carácter con delay del slider
   ├─ toggla WS_EX_TOPMOST del panel
   └─ config.json en %APPDATA%\ClipboardTyper\
   ▼
Campo con el foco
```

**Invariantes:**
- I1: la UI jamás llama a `SendInput`; solo publica estado.
- I2: el delay del slider se lee en el momento de pulsar el hotkey (cambio en caliente).
- I3:Keyboard hook global: si `RegisterHotKey` devuelve fallo por conflicto, se muestra aviso en la UI y **no** se registra parcialmente.
- I4: el panel debe poder ocultarse y mostrarse sin perder historial ni config.
- I5: ningún componente escribe fuera de `%LOCALAPPDATA%\ClipboardTyper\` y `%APPDATA%\ClipboardTyper\`.

### 5.3 Piezas

- **C1 — Host AHK v2 (Unicode x64, residente).** Registro del hotkey global, `OnClipboardChange`, historial acotado, `SendInput` con `KEYEVENTF_UNICODE` (acentos/ñ), toggle de `+E0x20` (always-on-top), persistencia de config, modo `--self-test`.
- **C2 — UI WebView2.`ui.html` con el diseño aprobado: fondo azul claro, tarjetas con icono de portapapeles, `overflow-y:auto` en `.list`, slider 5–100, chincheta toggle, botón de hotkey con captura, `Borrar todo`.
- **C3 — Puente.** `window.typerState = { getText, getDelay, isPinned, setAlwaysOnTop, setHotkey, resetHotkey }`. JS→AHK por `postMessage`, AHK→JS por `ExecuteScriptAsync`.
- **C4 — Config.** `%APPDATA%\ClipboardTyper\config.json`: `{ hotkey, delay_ms, always_on_top, version }`. Se escribe atómicamente (temp + rename).
- **C5 — Empaquetado.** Un `.exe` de Ahk2Exe que usa `FileInstall` para extraer `ui.html`, `bridge.testable.js` y `WebView2Loader.dll` a `%LOCALAPPDATA%\ClipboardTyper\` en el primer arranque. Nota de implementación (corrección menor al spec aprobado): el puente se prueba en Node como fichero separado, por lo que debe viajar en el `.zip`; el contenido final es `exe + ui.html + bridge.testable.js + WebView2Loader.dll + README.md`.

### 5.4 Partida de recursos (adaptación de §6)

No hay servicios, pero el host es residente: objetivo < 30 MB de RAM en reposo y 0 servicios, 0 tareas programadas, 0 puertos en escucha. El binario no debe crear entradas de inicio sin consentimiento explícito.

## 6. Contrato de recursos (partida de RAM) — OBLIGATORIO

`N/A (sin servicios afectados)`. La aplicación es un ejecutable de usuario en Windows, no un servicio del homelab; no hay LXC, contenedor ni manifiesto con `limits`. En su lugar aplica la restricción equivalente de §5.4: host residente < 30 MB, sin servicios ni tareas programadas. Por el mismo motivo no aplica `homelab-lint` (no hay H1/H8 que introducir).

## 7. Criterios de aceptación (medibles)

Los criterios marcados **[LINUX]** se ejecutan hoy en el entorno de desarrollo; los marcados **[WIN]** solo en el dispositivo de destino, con `ClipboardTyper.exe --self-test` o comprobación manual según la checklist de §13.

| Fase | Criterio + verificación (comando) | Valor esperado |
|---|---|---|
| Lógica | **[LINUX]** Extraer JS puro y `node --check` sobre `bridge.testable.js` | `exit 0`, sin errores de sintaxis |
| Lógica | **[LINUX]** `node --test tests/logic.test.js` | todos los tests pasan: normalizar `Ctrl+Shift+V`, clamp 5–100, round-trip config, truncar historial a 25 |
| UI | **[LINUX]** `node scripts/validate-ui.js` (parse HTML, verifica `.list` con `overflow-y:auto`, slider `min=5 max=100`, botones `pin`/`hk` presentes) | `OK` |
| Build | **[LINUX]** `bash scripts/package.sh` | genera `dist/ClipboardTyper-v1.0.0.zip` < 5 MB con `exe + ui.html + bridge.testable.js + WebView2Loader.dll + README.md` |
| Empaquetado | **[WIN]** `Expand-Archive ... ; Get-Item ClipboardTyper.exe \| Select Length` | descomprime sin error; exe presente; < 5 MB el zip |
| Runtime | **[WIN]** `ClipboardTyper.exe --self-test` | `selftest.log`: `webview2=OK hotkey=OK clipboard=OK sendinput=OK config=OK` |
| Historial | **[WIN]** copiar 30 textos distintos y abrir el panel | aparecen los 25 más recientes; scroll interno funciona; el panel no crece |
| Escritura | **[WIN]** seleccionar `Arturo García`, foco en un input, `Ctrl+Shift+V` | el input contiene `Arturo García` exacto, sin `Ctrl+V` |
| Acentos | **[WIN]** escribir `ñ á é í ó ú` | caracteres correctos (valida `KEYEVENTF_UNICODE`) |
| Velocidad | **[WIN]** slider a 5 y a 100, cronometrar 20 caracteres | tiempo ≈ 0,1 s y ≈ 2,0 s (±30 %) |
| Pin | **[WIN]** activar/desactivar chincheta | panel permanece/deja de permanecer encima al cambiar de ventana; estado persiste tras reinicio |
| Hotkey | **[WIN]** capturar `Alt+Q`, reiniciar, pulsar `Alt+Q` | escribe; `config.json` contiene `Alt + Q`; `Esc` cancela sin guardar |
| Conflicto | **[WIN]** asignar un hotkey ya ocupado | aviso visible, no se registra parcialmente, hotkey anterior sigue vivo |
| Rollback | **[LINUX]** `bash scripts/clean.sh` | elimina solo `dist/` y `build/`; no toca otros proyectos |

## 8. Riesgos y mitigación

| Riesgo | Mitigación |
|---|---|
| WebView2 Runtime ausente (Win10 o Win11 recortada) | Arranque detecta el runtime; si falta, muestra mensaje con enlace al bootstrapper Evergreen. El `.zip` puede incluirlo como descarga opcional, no embebido, para mantener el tamaño. |
| SmartScreen "Windows protegió tu PC" por exe sin firmar | v1: README explica el aviso y el paso "Más información → Ejecutar de todos modos". v1.1: firma OV/EV (EV da reputación inmediata; coste ~300–500 USD/año — deuda en §10). |
| Defender marca el AHK compilado como falso positivo | Misma mitigación; firma y, si reaparece, añadir exclusión documentada por usuario. |
| Conflicto de hotkey con otra app | `RegisterHotKey` devuelve fallo → aviso en UI (I3). |
| El hotkey escribe en la ventana equivocada | El foco es del sistema; se documenta en el README. No se intenta adivinar la ventana destino. |
| Formularios que bloquean `SendInput` o usan campos seguros | `SendInput` genera eventos confiables; se verifica en campo con la checklist. Fuera de alcance: controles de apps elevadas o escritorio seguro. |
| ARM64 | Ahk2Exe no produce binario ARM64 nativo; corre emulado. Declarar limitación en el README. |
| Sin prueba en campo en el entorno de desarrollo | §7 separa [LINUX]/[WIN] y §13 entrega autotest + checklist; el estado no puede pasar a `VERIFICADO` hasta que Arath ejecute la parte [WIN]. |

## 9. Rollback

- **Fase lógica/UI:** `bash scripts/clean.sh` borra `dist/` y `build/`. Confirmar: `test ! -d dist && echo OK`.
- **Fase empaquetado:** borrar el `.zip` de `dist/`. Confirmar: `ls dist/*.zip` devuelve "No such file".
- **Fase despliegue en Windows:** cerrar el proceso `ClipboardTyper.exe`, borrar `%LOCALAPPDATA%\ClipboardTyper\` y `%APPDATA%\ClipboardTyper\`. Confirmar: ambos paths no existen. No hay desinstalador en v1; la desinstalación es borrar carpetas.

## 10. Deuda fechada (visible)

| Deuda | Owner | Hasta |
|---|---|---|
| Firma de código (OV/EV) para eliminar avisos de SmartScreen/Defender | Arath | `2026-12-19` |
| Ejecutar la checklist de campo [WIN] en el dispositivo Windows y subir `selftest.log` | Arath | `2026-11-26` |
| Reevaluar Python como preprocesador si aparece el CSV con datos sucios | Arath | `2027-01-19` |

No hubo incidentes durante la redacción de este spec, por lo que no hay deuda por incidente (Art. 11.7).

## 11. Anexo — comandos de la evidencia

```bash
# §2 — punto de partida
uname -s
node --version
command -v AutoHotkey64.exe 2>/dev/null || echo "AHK: ausente (entorno Linux)"
test -f /mnt/homelab/projects/proxmox/docs/superpowers/templates/spec.md && echo "template canónico: OK"
test -d /root/clipboard-typer && echo "proyecto: existe" || echo "proyecto: no existe"

# §7 — verificable hoy
node --check src/bridge.testable.js
node --test tests/logic.test.js
node scripts/validate-ui.js
bash scripts/package.sh
bash scripts/clean.sh && test ! -d dist && echo OK
```

```powershell
# §7 — solo en el dispositivo Windows (no ejecutable aquí)
Expand-Archive -Path .\ClipboardTyper-v1.0.0.zip -DestinationPath .\ClipboardTyper
Get-Item .\ClipboardTyper\ClipboardTyper.exe | Select-Object Length
.\ClipboardTyper\ClipboardTyper.exe --self-test
Get-Content .\ClipboardTyper\selftest.log
Get-Content "$env:APPDATA\ClipboardTyper\config.json"
```

---

## 12. Instalación y distribución (requisito explícito de Arath)

**Objetivo:** descargar, descomprimir y usar en < 2 min, sin admin y sin asistente.

| Consideración | Decisión | Por qué |
|---|---|---|
| Formato | Un `.zip` con `ClipboardTyper.exe`, `ui.html`, `README.md` | Sin wizard; el usuario descomprime y ejecuta. |
| Tamaño | < 5 MB comprimido | Descarga rápida; WebView2 no se embebe (ya está en Win11). |
| Privilegios | Per-user: exe en `%LOCALAPPDATA%\ClipboardTyper\` | Sin UAC; no escribir en `Program Files`. |
| Dependencias | WebView2 Runtime (presente en Win11 21H2+). Bootstrapper solo si falta | Evita empaquetar ~100 MB del runtime. |
| Primera ejecución | `FileInstall` extrae `ui.html`; si falta WebView2, mensaje con enlace | Cero configuración manual. |
| Config | `%APPDATA%\ClipboardTyper\config.json`, escritura atómica | Separada del exe: portable sin perder ajustes. |
| Firma | Sin firmar en v1; EV en v1.1 (deuda §10) | Coste vs. fricción; se documenta el aviso de SmartScreen. |
| Autoarranque | No en v1 | Evita entrada de registro y fricción. |
| Desinstalar | Borrar `exe`, carpeta local y `config.json` | Sin desinstalador: operación reversible en 30 s. |
| Actualizar | Reemplazar el `.exe` desde GitHub Releases | Sin auto-update, sin red en runtime. |
| Idioma | Interfaz en español | Usuario hispanohablante. |
| Arquitectura | x64 (emulado en ARM64, limitación documentada) | Ahk2Exe no genera ARM64 nativo. |
| Red en runtime | Ninguna (salvo que el usuario abra el enlace del bootstrapper) | Sin telemetría ni endpoints. |

## 13. Estrategia de verificación sin dispositivo Windows

**Principio:** no se puede ejecutar AHK, WebView2 ni `SendInput` en este host Linux (hecho medido en §2). Por tanto el estado del spec no puede llegar a `VERIFICADO` sin la parte [WIN].

**Parte A — verificable hoy (articulate en `scripts/`):**
1. Extraer la lógica pura a `src/bridge.testable.js` (normalizar hotkey, clamp de delay, round-trip de config, tope de historial) y testearla con `node --test`.
2. Validar `ui.html` estáticamente: parse, presencia de `.list` con `overflow-y:auto`, slider `min=5 max=100`, ids `pin` y `hk`.
3. Revisión estática del `.ahk`: comprueba que no hay comandos de red, que `SendInput` aparece una sola vez y que la ruta de config es la declarada.
4. Generar el `.zip` y verificar su tamaño y contenido.

**Parte B — checklist que ejecuta Arath en el dispositivo Windows:**
1. Copiar 30 textos → el panel muestra 25, con scroll interno.
2. Seleccionar `Arturo García` → `Ctrl+Shift+V` → el input contiene `Arturo García`.
3. Escribir `ñ á é í ó ú` → acentos correctos.
4. Slider a 5 y a 100 →cronometrar 20 caracteres → ≈0,1 s y ≈2,0 s.
5. Chincheta on/off → el panel permanece / no permanece encima; reiniciar y comprobar persistencia.
6. Capturar `Alt+Q`, reiniciar, pulsar `Alt+Q` → escribe; `Esc` cancela.
7. Asignar hotkey ocupado → aviso visible, hotkey anterior intacto.
8. Ejecutar `--self-test` y adjuntar `selftest.log` al cierre de la feature.

**Regla de cierre:** el plan puede pasar a `IMPLEMENTADO` con la Parte A en verde; solo pasa a `VERIFICADO` cuando la Parte B esté completada y se registre `selftest.log`.

## 14. Decisiones tomadas (registro)

| Decisión | Valor | Origen |
|---|---|---|
| Motor de escritura | `SendInput` desde AHK, nunca desde la GUI | Restricción `isTrusted` analizada en la sesión |
| UI | WebView2 con HTML/CSS embebido | Aprobación del mockup por Arath |
| Motor de UI alternativo si falta WebView2 | Mensaje + bootstrapper; sin fallback nativo en v1 | Alcance acotado (§4) |
| Hotkey global vs. solo panel | **Global** (decisión por defecto del arquitecto; Arath no lo confirmó explícitamente) | Es la única forma útil de rellenar formularios sin volver al panel. Si Arath quiere solo-panel, cambiar C1 y el criterio de aceptación correspondiente. |
| Cómo se muestra el panel | Clic en icono de bandeja del sistema (muestra/oculta); si está anclado, permanece visible. No se añade segundo hotkey en v1 | El mockup aprobado solo tiene un campo de activación (el de escritura). Una bandeja resuelve el acceso sin cambiar la UI. Decisión del arquitecto, no confirmada explícitamente por Arath. |
| `Borrar todo` | Vacía el historial; NO toca `config.json` (velocidad, pin y hotkey sobreviven) | El botón está junto al historial, no entre los ajustes. |
| Límite de historial | 25 entradas | Coherente con el panel Win+V y con el ACL de 316 campos |
| CSV | Fuera de v1; Python como preprocesador solo si el CSV es sucio | Conversación previa con Arath |
| Tipo de distribución | Portable per-user, sin firma en v1 | Requisito de instalación rápida y simple |
