const fs = require('node:fs')
const assert = require('node:assert/strict')

const src = fs.readFileSync('src/ClipboardTyper.ahk', 'utf8')
const required = [
  '#Requires AutoHotkey v2.0',
  'OnClipboardChange',
  'CF_UNICODETEXT',
  'RegisterHotKey',
  'KEYEVENTF_UNICODE',
  'SendInput',
  'ExecuteScriptAsync',
  'WebMessageReceived',
  'WebView2Loader.dll',
  'A_AppData',
  'A_LocalAppData',
  '--self-test',
  'selftest.log',
  'WebView2',
]
for (const token of required) {
  assert.ok(src.includes(token), `falta en ClipboardTyper.ahk: ${token}`)
}
assert.match(src, /if\s*\([^\n]*CF_UNICODETEXT[^\n]*\)\s*\{\s*return/, 'debe ignorar portapapeles no textual')
