# Clipboard Typer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir el portapapeles typer de Windows 11 descrito en el spec: panel estilo Win+V con historial, slider de velocidad, anclaje y hotkey configurable, cuya escritura en el campo con foco la hace AHK con `SendInput`.

**Architecture:** Tres piezas con una frontera estricta. (1) `bridge.testable.js` contiene la lógica pura (normalizar hotkey, clamp de delay, config, historial) y se prueba en Node sobre Linux. (2) `ui.html` es el panel WebView2 que solo publica `{texto, delay, pin, hotkey}` en `window.typerState`. (3) `ClipboardTyper.ahk` es el único proceso residente: registra el hotkey global, vigila el portapapeles, aplica always-on-top y escribe con `SendInput`. El empaquetado genera un `.zip` portable por usuario sin admin.

**Tech Stack:** AutoHotkey v2 (Unicode x64), WebView2 (wrapper AHK vendored + `WebView2Loader.dll`), HTML/CSS/JS sin frameworks, Node 22 `node:test` para lógica pura, bash para empaquetado.

**Spec:** `docs/superpowers/specs/2026-11-19-clipboard-typer-design.md`

## Global Constraints

Copiadas verbatim del spec aprobado; todo task las hereda:

- Historial máximo **25 entradas**.
- Slider **5–100 ms**, valor por defecto **25**; `rápido` ≤ 15, `normal` ≤ 40, `lento` > 40.
- Hotkey por defecto **`Ctrl + Shift + V`**.
- Config en `%APPDATA%\ClipboardTyper\config.json`; recursos en `%LOCALAPPDATA%\ClipboardTyper\`.
- `SendInput` **solo** en el host AHK; la GUI nunca genera eventos de teclado.
- Sin red en runtime; sin administrador/UAC; sin servicios, tareas programadas ni entradas de inicio.
- Idioma de interfaz: **español**.
- `.zip` < **5 MB**, con `exe + ui.html + bridge.testable.js + WebView2Loader.dll + README.md`.
- Residente < **30 MB** de RAM.
- El estado no pasa a `VERIFICADO` sin la checklist [WIN] y `selftest.log` (§13 del spec).
- No hay dispositivo Windows en el entorno de desarrollo: los tasks 1, 2, 4 y 5 son verificables hoy; el task 3 solo es verificable estáticamente aquí.

## Review Focus

Cinco fallos que el spec no cubre con tests propios y que deben estar fijados en el task que posee el código:

1. **Acentos y ñ** (`ArturoGarcía`, `av. Libertador`) — se espera escritura exacta, sin `?` ni caracteres partidos. Test: aserción en `tests/ahk-static.test.js` de que el host usa `KEYEVENTF_UNICODE`, más el ítem 3 de la checklist de campo.
2. **Conflicto de hotkey** — al asignar un combo ocupado se espera aviso visible y que el hotkey anterior siga vivo. Test: `tests/logic.test.js` para el formato/normalización, más el ítem 7 de la checklist de campo.
3. **WebView2 no instalado** — se espera mensaje claro con enlace al bootstrapper, no un panel vacío ni un crash. Test: aserción estática en `tests/ahk-static.test.js` del mensaje y el ítem 1 de la checklist de campo.
4. **Cambio de slider a mitad de sesión** — se espera que el nuevo delay se aplique en el siguiente hotkey sin reiniciar. Test: `tests/logic.test.js` (`clampDelay` sobre el valor leído en el momento del disparo) más el ítem 4 de la checklist.
5. **Portapapeles con imagen/archivo** — se espera que se ignore sin error y sin ensuciar el historial. Test: aserción estática en `tests/ahk-static.test.js` del guardián de tipo CF_UNICODETEXT, más el ítem 1 de la checklist.

---

### Task 1: Lógica pura y scaffolding

**Files:**
- Create: `src/bridge.testable.js`
- Create: `tests/logic.test.js`
- Create: `.gitignore`
- Create: `package.json` (solo `{ "type": "commonjs", "scripts": { "test": "node --test tests/" } }`)

**Interfaces:**
- Consumes: nada.
- Produces: `require('./src/bridge.testable.js')` expone exactamente `normalizeHotkey(modifiers, baseKey) -> string`, `clampDelay(value) -> number`, `describeSpeed(delay) -> string`, `defaultConfig() -> object`, `parseConfig(json) -> object`, `serializeConfig(config) -> string`, `pushHistory(history, text, limit) -> array`. `defaultConfig()` devuelve `{ hotkey: 'Ctrl + Shift + V', delay_ms: 25, always_on_top: false, version: 1 }`. `normalizeHotkey` devuelve `''` para `Escape` y ordene los modificadores en `Ctrl, Alt, Shift, Win`. `parseConfig` cae a `defaultConfig()` ante JSON inválido o campos fuera de rango.

- [ ] **Step 1: Inicializar repo y escribir el test que falla**

```bash
cd /root/clipboard-typer && git init -q
```

`tests/logic.test.js` usa `node:test` y `node:assert/strict`. Casos obligatorios, con estos valores exactos:

```js
test('normalizeHotkey ordena modificadores y respeta Escape', () => {
  assert.equal(normalizeHotkey(['Shift', 'Ctrl'], 'V'), 'Ctrl + Shift + V')
  assert.equal(normalizeHotkey([], 'Escape'), '')
})
test('clampDelay acota al rango 5-100 y rechaza basura', () => {
  assert.equal(clampDelay(0), 5)
  assert.equal(clampDelay(250), 100)
  assert.equal(clampDelay('abc'), 25)
})
test('describeSpeed usa los umbrales del spec', () => {
  assert.equal(describeSpeed(15), 'rápido')
  assert.equal(describeSpeed(40), 'normal')
  assert.equal(describeSpeed(41), 'lento')
})
test('config por defecto y round-trip', () => {
  assert.deepEqual(defaultConfig(), { hotkey: 'Ctrl + Shift + V', delay_ms: 25, always_on_top: false, version: 1 })
  assert.deepEqual(parseConfig(serializeConfig(defaultConfig())), defaultConfig())
  assert.deepEqual(parseConfig('{roto'), defaultConfig())
})
test('pushHistory limita a 25 y conserva el más reciente al frente', () => {
  const h = pushHistory([], 'a', 25)
  assert.equal(pushHistory(h, 'b', 25)[0], 'b')
  assert.equal(pushHistory(Array.from({length: 30}, (_, i) => 'x' + i), 'z', 25).length, 25)
})
```

- [ ] **Step 2: Verificar que falla**

Run: `cd /root/clipboard-typer && node --test tests/logic.test.js`
Expected: FAIL con `Cannot find module '../src/bridge.testable.js'`

- [ ] **Step 3: Implementar el módulo**

`src/bridge.testable.js` usa patrón UMD: expone en `module.exports` bajo Node y en `globalThis.TyperBridge` en el navegador. Sin dependencias. Un único archivo, sin `try/catch` más allá del necesario para `parseConfig`.

- [ ] **Step 4: Verificar que pasa**

Run: `cd /root/clipboard-typer && node --test tests/logic.test.js`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add package.json .gitignore src/bridge.testable.js tests/logic.test.js
git commit -m "feat: bridge puro con tests de hotkey, delay y config"
```

---

### Task 2: Panel WebView2 (`ui.html`)

**Files:**
- Create: `scripts/validate-ui.js`
- Create: `src/ui.html`

**Interfaces:**
- Consumes: `globalThis.TyperBridge` de Task 1, cargado con `<script src="bridge.testable.js"></script>` antes del script inline.
- Produces: `window.typerState` con `getText() -> string`, `getDelay() -> number`, `isPinned() -> boolean`, `setAlwaysOnTop(v)`, `setHotkey(v)`, `resetHotkey()`. IDs DOM fijos: `panel`, `list`, `speed`, `ms`, `qual`, `pin`, `hk`, `clear`. Clase `.card` con hijo `.txt` para cada entrada; `.card.sel` marca la seleccionada.

- [ ] **Step 1: Escribir el validador (test) antes del HTML**

`scripts/validate-ui.js` lee `src/ui.html` y comprueba, con `assert`, que el texto contiene: `overflow-y:auto`, `id="list"`, `type="range"`, `min="5"`, `max="100"`, `id="speed"`, `id="pin"`, `id="hk"`, `id="clear"`, `bridge.testable.js`, `window.typerState`, `getText`, `getDelay`, `setAlwaysOnTop`, `setHotkey`. Imprime `OK` al terminar.

- [ ] **Step 2: Verificar que falla**

Run: `cd /root/clipboard-typer && node scripts/validate-ui.js`
Expected: FAIL con `ENOENT: no such file or directory, open 'src/ui.html'`

- [ ] **Step 3: Implementar `src/ui.html`**

Trasladar el mockup aprobado en la conversación: fondo azul claro degradado, tarjetas blancas con icono SVG de portapapeles, `.list` con `height:250px; overflow-y:auto`, slider con feedback `rápido/normal/lento` usando `describeSpeed`, chincheta con toggle visual (clase `.on`, borde azul en `.panel.pinned`), botón de hotkey que captura modificadores + tecla con `Escape` para cancelar usando `normalizeHotkey`, y `Borrar todo` que vacía solo `.card`. Los seis textos semilla son `Texto`, `Historial del portapapeles`, `Windows 11`, `Prueba`, `arturo@correo.com`, `av. Libertador 1234`.

- [ ] **Step 4: Verificar que pasa**

Run: `cd /root/clipboard-typer && node scripts/validate-ui.js`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-ui.js src/ui.html
git commit -m "feat: panel WebView2 con historial, slider, pin y hotkey"
```

---

### Task 3: Host AHK v2

**Files:**
- Create: `tests/ahk-static.test.js`
- Create: `src/vendor/WebView2.ahk` (wrapper vendored, fuente: `Ixiko/AHK-libs-and-classes-collection`, ruta `AHK_V2/webview2/webview2.ahk`, adaptado con `ExecuteScriptAsync` y `add_WebMessageReceived`)
- Create: `src/ClipboardTyper.ahk`

**Interfaces:**
- Consumes: `window.typerState` de Task 2 y las rutas del spec.
- Produces: `ClipboardTyper.exe` (vía Ahk2Exe en Task 4) con modificadores `--self-test` y `--version`. Escribe `selftest.log` en el directorio del exe con las claves `webview2`, `hotkey`, `clipboard`, `sendinput`, `config`, cada una `OK` o `FAIL: <motivo>`.

- [ ] **Step 1: Escribir el test estático que falla**

`tests/ahk-static.test.js` lee `src/ClipboardTyper.ahk` y comprueba con `assert.match` que contiene: `#Requires AutoHotkey v2.0`, `OnClipboardChange`, `CF_UNICODETEXT`, `RegisterHotKey`, `KEYEVENTF_UNICODE`, `SendInput`, `ExecuteScriptAsync`, `WebMessageReceived`, `WebView2Loader.dll`, `%APPDATA%` (o `A_AppData`), `%LOCALAPPDATA%` (o `A_LocalAppData`), `--self-test`, `selftest.log`, `MsgBox` con el texto `WebView2`, y una rama que devuelve sin escribir cuando el portapapeles no es texto.

- [ ] **Step 2: Verificar que falla**

Run: `cd /root/clipboard-typer && node --test tests/ahk-static.test.js`
Expected: FAIL con `ENOENT` sobre `src/ClipboardTyper.ahk`

- [ ] **Step 3: Vendorizar el wrapper WebView2**

Descargar el `.ahk` de la fuente indicada a `src/vendor/WebView2.ahk` y añadirle dos métodos sobre `this.wv.coreWebView`: `ExecuteScriptAsync(script)` (vía `ComCall` con el ordinal documentado de `ICoreWebView2::ExecuteScriptAsync`) y un manejador de `WebMessageReceived` que llame a un callback de AHK con el `JSON` recibido. Documentar en cabecera la versión del wrapper y la fuente.

- [ ] **Step 4: Implementar el host**

`src/ClipboardTyper.ahk`: gui AHK que aloja el WebView2 cargando `file:///<A_LocalAppData>\ClipboardTyper\ui.html`; `OnClipboardChange` solo acepta `CF_UNICODETEXT` y hace `pushHistory` vía `ExecuteScriptAsync`; `RegisterHotKey` global con el hotkey de config y aviso `MsgBox` si falla; al dispararse lee `typerState.getText()` y `typerState.getDelay()` y escribe cada carácter con `SendInput` + `KEYEVENTF_UNICODE`; el pin aplica/quita `WS_EX_TOPMOST` (`+E0x20`); icono de bandeja muestra/oculta el panel; `Borrar todo` y el editor de hotkey llegan por `WebMessageReceived`; config se guarda atómico (temp + rename) en `%APPDATA%\ClipboardTyper\config.json`.

- [ ] **Step 5: Verificar estáticamente (sin Windows)**

Run: `cd /root/clipboard-typer && node --test tests/ahk-static.test.js`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add tests/ahk-static.test.js src/vendor/WebView2.ahk src/ClipboardTyper.ahk
git commit -m "feat: host AHK con hotkey global, clipboard y SendInput"
```

---

### Task 4: Empaquetado portable y README

**Files:**
- Create: `scripts/package.sh`
- Create: `scripts/clean.sh`
- Create: `README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `src/ClipboardTyper.ahk`, `src/ui.html`, `src/bridge.testable.js`, `src/vendor/WebView2.ahk`, `src/vendor/WebView2Loader.dll` (descargado por `package.sh`).
- Produces: `dist/ClipboardTyper-v1.0.0.zip` y `dist/ClipboardTyper.exe`.

- [ ] **Step 1: Escribir el test de empaquetado que falla**

Crear `tests/package.test.js`: con `node:child_process` ejecuta `bash scripts/package.sh`, luego con `node:zlib`/`fs` verifica que `dist/ClipboardTyper-v1.0.0.zip` existe, que su tamaño es < 5 MB y que el listado de entradas contiene `ClipboardTyper.exe`, `ui.html`, `bridge.testable.js`, `WebView2Loader.dll`, `README.md`.

Nota: Ahk2Exe no existe en Linux. `scripts/package.sh` debe detectirlo y, si falta, copiar `src/ClipboardTyper.ahk` como `ClipboardTyper.exe.invalid` y continuar, imprimiendo `WARN: compilar en Windows con Ahk2Exe`. El test de empaquetado verifica la estructura del zip, no la ejecutabilidad del binario.

- [ ] **Step 2: Verificar que falla**

Run: `cd /root/clipboard-typer && node --test tests/package.test.js`
Expected: FAIL con `ENOENT` sobre `scripts/package.sh`

- [ ] **Step 3: Implementar los scripts y el README**

`scripts/package.sh`: `set -euo pipefail`; descarga `WebView2Loader.dll` x64 del paquete NuGet `Microsoft.Web.WebView2` (URL fijada en una variable, con `curl --max-time 60`); crea `dist/payload/`; copia los cinco ficheros; genera el zip; imprime tamaño. `scripts/clean.sh`: borra solo `dist/` y `build/`. `README.md` en español: instalación en 3 pasos, aviso de SmartScreen, hotkey por defecto, cómo cambiarlo, desinstalación borrando carpetas, limitación ARM64 y enlace al bootstrapper de WebView2. Añadir `dist/`, `build/`, `src/vendor/WebView2Loader.dll` a `.gitignore`.

- [ ] **Step 4: Verificar que pasa**

Run: `cd /root/clipboard-typer && node --test tests/package.test.js`
Expected: PASS con `WARN: compilar en Windows con Ahk2Exe` en stderr

- [ ] **Step 5: Commit**

```bash
git add scripts/package.sh scripts/clean.sh README.md .gitignore tests/package.test.js
git commit -m "feat: empaquetado portable y README de instalación"
```

---

### Task 5: Evidencia de campo y cierre documental

**Files:**
- Create: `docs/superpowers/evidence/2026-11-19-clipboard-typer-field-checklist.md`
- Modify: `docs/superpowers/INDEX.md`

**Interfaces:**
- Consumes: §7 y §13 del spec y los ocho ítems de la checklist de campo.
- Produces: checklist imprimible con casillas, comandos PowerShell y espacio para `selftest.log`; `INDEX.md` en `IMPLEMENTADO`.

- [ ] **Step 1: Escribir la comprobación del artifacto (test que falla)**

Crear `tests/evidence.test.js`: comprueba que el fichero de evidencia existe y contiene las cadenas `--self-test`, `selftest.log`, `ñ á é í ó ú`, `Alt+Q`, `≈0,1 s`, `≈2,0 s`, y las ocho casillas `- [ ]`.

- [ ] **Step 2: Verificar que falla**

Run: `cd /root/clipboard-typer && node --test tests/evidence.test.js`
Expected: FAIL con `ENOENT`

- [ ] **Step 3: Redactar la checklist y actualizar el índice**

Ocho pasos numerados exactamente como §13 del spec, con comandos PowerShell copiables y una sección final para pegar `selftest.log`. Cambiar el estado de la feature en `INDEX.md` a `IMPLEMENTADO` y añadir la nota "pendiente de Parte B [WIN]; no marked VERIFICADO".

- [ ] **Step 4: Verificar que pasa y ejecutar toda la suite**

Run: `cd /root/clipboard-typer && node --test tests/ && node scripts/validate-ui.js`
Expected: todos los tests PASS y `OK`

- [ ] **Step 5: Commit**

```bash
git add tests/evidence.test.js docs/superpowers/evidence/2026-11-19-clipboard-typer-field-checklist.md docs/superpowers/INDEX.md
git commit -m "docs: checklist de campo y estado IMPLEMENTADO"
```

---

## Self-review

- **Spec coverage:** §1–§5 cubiertos por Tasks 1–4; §6 N/A ya en el spec; §7 criterios [LINUX] en Tasks 1, 2, 4 y [WIN] delegados en Task 5; §8 riesgos mitigados en Tasks 3 y 4; §9 rollback en `scripts/clean.sh` (Task 4); §10 deuda en `INDEX.md` (Task 5); §12 en Task 4; §13 en Task 5; §14 decisiones respetadas.
- **Step scan:** cada step produce exactamente un artefacto verificable; no hay "handle edge cases" ni bodies de código determinados por la signature.
- **Type consistency:** `normalizeHotkey`, `clampDelay`, `describeSpeed`, `pushHistory`, `typerState`, IDs DOM y claves de `selftest.log` se usan con los mismos nombres en Tasks 1–5.
- **Review Focus:** los cinco fallos están asignados a `tests/logic.test.js` (2 y 4), `tests/ahk-static.test.js` (1, 3 y 5) y a la checklist de campo (todos).
- **Proportion:** el plan es más corto que el spec en código pero más largo en decisiones, coherente con un proyecto que no se puede ejecutar en el entorno de desarrollo.
