const fs = require('node:fs')
const assert = require('node:assert/strict')

const install = fs.readFileSync('scripts/install-windows.ps1', 'utf8')
for (const token of [
  'SkipDependencies',
  'winget',
  'AutoHotkey.AutoHotkey',
  'Microsoft.WebView2Runtime',
  'LinkId=2124703',
  'api.github.com/repos/AutoHotkey/AutoHotkey/releases/latest',
  '/SILENT',
  'Start Menu',
  'CreateShortcut',
  'CurrentVersion\\Uninstall',
  'uninstall-windows.ps1',
]) {
  assert.ok(install.includes(token), `falta en install-windows.ps1: ${token}`)
}

const uninstall = fs.readFileSync('scripts/uninstall-windows.ps1', 'utf8')
for (const token of [
  'Stop-Process',
  'Remove-Item',
  'CurrentVersion\\Uninstall',
  'Start Menu',
  'LOCALAPPDATA',
]) {
  assert.ok(uninstall.includes(token), `falta en uninstall-windows.ps1: ${token}`)
}
