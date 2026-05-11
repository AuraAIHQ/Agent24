// M2: Module enable/disable state — persisted to ~/.agent24/module-state.json

import fs from 'node:fs'
import path from 'node:path'
import os from 'node:os'

const STATE_DIR = path.join(os.homedir(), '.agent24')
const STATE_FILE = path.join(STATE_DIR, 'module-state.json')

// State: Record<moduleId, enabled>. Default is enabled (true) if not set.
let _state: Record<string, boolean> = {}

export function loadState(): void {
  try {
    _state = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8')) as Record<string, boolean>
  } catch { _state = {} }
}

export function isEnabled(moduleId: string): boolean {
  return _state[moduleId] !== false  // default: enabled
}

export function setEnabled(moduleId: string, enabled: boolean): void {
  _state[moduleId] = enabled
  try {
    fs.mkdirSync(STATE_DIR, { recursive: true })
    fs.writeFileSync(STATE_FILE, JSON.stringify(_state, null, 2))
  } catch { /* best-effort */ }
}

export function getAllState(): Record<string, boolean> {
  return { ..._state }
}
