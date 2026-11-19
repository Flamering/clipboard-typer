const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const { execFileSync } = require('node:child_process')

const zip = 'dist/ClipboardTyper-v1.0.0.zip'

test('package.sh genera un zip portable con los cinco artefactos', { timeout: 120000 }, () => {
  execFileSync('bash', ['scripts/package.sh'], { encoding: 'utf8', stdio: 'pipe' })

  assert.ok(fs.existsSync(zip), `no existe ${zip}`)
  const bytes = fs.statSync(zip).size
  assert.ok(bytes < 5 * 1024 * 1024, `zip demasiado grande: ${bytes} bytes`)

  const listing = execFileSync('unzip', ['-Z1', zip], { encoding: 'utf8' })
  for (const name of [
    'ClipboardTyper.exe',
    'ui.html',
    'bridge.testable.js',
    'WebView2Loader.dll',
    'README.md',
  ]) {
    assert.ok(listing.split('\n').includes(name), `falta en el zip: ${name}`)
  }
})
