const fs = require('node:fs')
const assert = require('node:assert/strict')

const html = fs.readFileSync('src/ui.html', 'utf8')
const required = [
  'overflow-y:auto',
  'id="list"',
  'type="range"',
  'min="5"',
  'max="100"',
  'id="speed"',
  'id="pin"',
  'id="hk"',
  'id="clear"',
  'bridge.testable.js',
  'window.typerState',
  'getText',
  'getDelay',
  'setAlwaysOnTop',
  'setHotkey',
]
for (const token of required) {
  assert.ok(html.includes(token), `falta en ui.html: ${token}`)
}
console.log('OK')
