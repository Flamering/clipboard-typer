# Checklist de campo — portapapeles typer

**Dispositivo:** Windows 11 (x64) · **Fecha:** ___________  · **Ejecutado por:** Arath

Esta checklist es la Parte B de la verificación (spec §13). Solo se puede ejecutar en el equipo Windows. No marques el spec como `VERIFICADO` hasta completarla y adjuntar `selftest.log`.

## Comandos previos (PowerShell)

```powershell
Expand-Archive -Path .\ClipboardTyper-v1.0.0.zip -DestinationPath .\ClipboardTyper
Get-Item .\ClipboardTyper\ClipboardTyper.exe | Select-Object Length
.\ClipboardTyper\ClipboardTyper.exe --self-test
Get-Content .\ClipboardTyper\selftest.log
Get-Content "$env:APPDATA\ClipboardTyper\config.json"
```

Resultado esperado de `--self-test`: `webview2=OK`, `hotkey=OK`, `clipboard=OK`, `sendinput=OK`, `config=OK`, `ui=OK`.

## Pasos

- [ ] **1. Despliegue y runtime.** Descomprime, ejecuta y comprueba que el panel aparece con el degradado azul y las seis tarjetas de ejemplo. Si sale un aviso de WebView2, instala el Evergreen Runtime y repite. Sin crash ni panel vacío.
- [ ] **2. Historial y scroll interno.** Copia 30 textos distintos. El panel muestra los 25 más recientes; la lista tiene scroll vertical propio y el panel no crece. Los elementos no textuales (imagen/archivo) no se añaden ni producen error.
- [ ] **3. Escritura exacta y acentos.** Selecciona `Arturo García`, pon el foco en un input y pulsa `Ctrl + Shift + V`. El input queda exactamente `Arturo García`. Repite con `ñ á é í ó ú` y con `av. Libertador 1234`: sin `?`, sin caracteres partidos, sin orden invertido.
- [ ] **4. Velocidad.** Pon el slider a 5 ms y cronometra 20 caracteres: ≈0,1 s (±30 %). Ponlo a 100 ms y repite: ≈2,0 s (±30 %). Cambia el slider a mitad de sesión y comprueba que el siguiente disparo usa el nuevo valor sin reiniciar.
- [ ] **5. Anclaje.** Activa la chincheta: el borde se vuelve azul y el panel permanece encima al cambiar de ventana. Desactívalo: deja de permanecer. Reinicia y comprueba que el estado se conserva.
- [ ] **6. Hotkey configurable.** Pulsa el botón de activación, captura `Alt+Q`, reinicia y pulsa `Alt+Q`: se escribe. `config.json` contiene `Alt + Q`. Durante la captura, `Esc` cancela y restaura `Ctrl + Shift + V`.
- [ ] **7. Conflicto de hotkey.** Asigna un combo ya ocupado por otra aplicación. Aparece el aviso, no se registra parcialmente y el hotkey anterior sigue funcionando.
- [ ] **8. Persistencia y borrado.** Cambia velocidad, pin y hotkey; cierra y reabre: todo se conserva. `Borrar todo` vacía el historial sin tocar esos tres ajustes.

## Resultado

`selftest.log` (pegar aquí):

```
```

Firma: ______________________

**Cierre:** si los 8 pasos están marcados y el autotest está en verde, actualiza `docs/superpowers/INDEX.md` a `VERIFICADO`. Si falla algo, abre una deuda fechada con owner y `until`.
