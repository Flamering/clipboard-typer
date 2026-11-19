const fs = require('node:fs')
const assert = require('node:assert/strict')

const path = 'docs/superpowers/evidence/2026-11-19-clipboard-typer-field-checklist.md'
const doc = fs.readFileSync(path, 'utf8')
for (const token of [
  '--self-test',
  'selftest.log',
  'ñ á é í ó ú',
  'Alt+Q',
  '≈0,1 s',
  '≈2,0 s',
]) {
  assert.ok(doc.includes(token), `falta en la checklist: ${token}`)
}
const boxes = doc.match(/^- \[ \]/gm) || []
assert.ok(boxes.length >= 8, `faltan casillas: ${boxes.length}`)
