const { test } = require('node:test')
const assert = require('node:assert/strict')
const {
  normalizeHotkey,
  clampDelay,
  describeSpeed,
  defaultConfig,
  parseConfig,
  serializeConfig,
  pushHistory,
} = require('../src/bridge.testable.js')

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
  assert.deepEqual(defaultConfig(), {
    hotkey: 'Ctrl + Shift + V',
    delay_ms: 25,
    always_on_top: false,
    version: 1,
  })
  assert.deepEqual(parseConfig(serializeConfig(defaultConfig())), defaultConfig())
  assert.deepEqual(parseConfig('{roto'), defaultConfig())
})

test('pushHistory limita a 25 y conserva el más reciente al frente', () => {
  const h = pushHistory([], 'a', 25)
  assert.equal(pushHistory(h, 'b', 25)[0], 'b')
  assert.equal(
    pushHistory(Array.from({ length: 30 }, (_, i) => 'x' + i), 'z', 25).length,
    25,
  )
})
