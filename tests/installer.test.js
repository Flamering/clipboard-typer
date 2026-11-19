const fs = require('node:fs')
const assert = require('node:assert/strict')

const src = fs.readFileSync('scripts/install-windows.ps1', 'utf8')
for (const token of [
  'param(',
  '$Ahk2Exe',
  'Ahk2Exe.exe',
  'WebView2Loader.dll',
  'LOCALAPPDATA',
  'ui.html',
  'bridge.testable.js',
  'ClipboardTyper.ahk',
]) {
  assert.ok(src.includes(token), `falta en install-windows.ps1: ${token}`)
}
