// BoxLite Host — singleton availability check and CodeBox factory.
// BoxLite requires the platform-native NAPI binding (@boxlite-ai/boxlite-darwin-arm64 on M-series).
// If the binding is unavailable (CI, wrong platform) all APIs return a graceful error.

let CodeBoxClass: (new () => { run(code: string): Promise<string>; stop(): Promise<void> }) | null = null
let initError: string | null = null
let initialized = false

function ensureInit(): void {
  if (initialized) return
  initialized = true
  try {
    // Dynamic require to avoid top-level import failure when native binding is absent.
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const mod = require('@boxlite-ai/boxlite') as { CodeBox: typeof CodeBoxClass }
    CodeBoxClass = mod.CodeBox
    console.log('[boxlite] native binding loaded')
  } catch (err) {
    initError = err instanceof Error ? err.message : String(err)
    console.warn('[boxlite] native binding unavailable:', initError)
  }
}

export function isBoxliteAvailable(): boolean {
  ensureInit()
  return CodeBoxClass !== null
}

export function getBoxliteError(): string | null {
  ensureInit()
  return initError
}

/** Run Python code in an isolated CodeBox. Box is started fresh and stopped after each run. */
export async function runPython(code: string): Promise<{ ok: true; output: string } | { ok: false; error: string }> {
  ensureInit()
  if (!CodeBoxClass) {
    return { ok: false, error: `BoxLite unavailable: ${initError}` }
  }
  const box = new CodeBoxClass()
  try {
    const output = await box.run(code)
    return { ok: true, output }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    return { ok: false, error: message }
  } finally {
    await box.stop().catch(() => {/* best-effort cleanup */})
  }
}
