/*
 * Lógica pura del portapapeles typer. Sin dependencias.
 * Funciona igual en Node (module.exports) y en WebView2 (globalThis.TyperBridge).
 */
(function (root, factory) {
  const api = factory()
  if (typeof module === 'object' && module.exports) module.exports = api
  else root.TyperBridge = api
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict'

  const MODIFIER_ORDER = ['Ctrl', 'Alt', 'Shift', 'Win']
  const DEFAULT_CONFIG = Object.freeze({
    hotkey: 'Ctrl + Shift + V',
    delay_ms: 25,
    always_on_top: false,
    version: 1,
  })

  function normalizeHotkey(modifiers, baseKey) {
    if (baseKey === 'Escape') return ''
    const keys = Array.isArray(modifiers) ? modifiers : []
    const present = MODIFIER_ORDER.filter((m) => keys.includes(m) || keys.includes(m === 'Win' ? 'Meta' : m))
    const base = typeof baseKey === 'string' && baseKey ? baseKey : ''
    return present.concat(base ? [base] : []).join(' + ')
  }

  function clampDelay(value) {
    const n = typeof value === 'number' ? value : parseInt(value, 10)
    if (!Number.isFinite(n)) return DEFAULT_CONFIG.delay_ms
    return Math.min(100, Math.max(5, Math.round(n)))
  }

  function describeSpeed(delay) {
    const ms = clampDelay(delay)
    if (ms <= 15) return 'rápido'
    if (ms <= 40) return 'normal'
    return 'lento'
  }

  function defaultConfig() {
    return { ...DEFAULT_CONFIG }
  }

  function parseConfig(json) {
    const fallback = defaultConfig()
    if (typeof json !== 'string' || !json.trim()) return fallback
    let raw
    try {
      raw = JSON.parse(json)
    } catch (_) {
      return fallback
    }
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return fallback
    const hotkey = typeof raw.hotkey === 'string' && raw.hotkey.trim() ? raw.hotkey : fallback.hotkey
    const delay_ms = clampDelay(
      Number.isFinite(raw.delay_ms) ? raw.delay_ms : fallback.delay_ms,
    )
    const always_on_top = typeof raw.always_on_top === 'boolean' ? raw.always_on_top : fallback.always_on_top
    return { hotkey, delay_ms, always_on_top, version: fallback.version }
  }

  function serializeConfig(config) {
    return JSON.stringify(parseConfig(JSON.stringify(config || {})))
  }

  function pushHistory(history, text, limit) {
    if (typeof text !== 'string' || !text) return Array.isArray(history) ? history.slice() : []
    const max = Number.isFinite(limit) && limit > 0 ? limit : 25
    const prev = Array.isArray(history) ? history.filter((v) => typeof v === 'string') : []
    return [text].concat(prev.filter((v) => v !== text)).slice(0, max)
  }

  return {
    normalizeHotkey,
    clampDelay,
    describeSpeed,
    defaultConfig,
    parseConfig,
    serializeConfig,
    pushHistory,
  }
})
