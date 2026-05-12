// BoxLite Service Container Manager — M4
// Manages long-running OCI service containers via BoxLite SimpleBox.
// Each module with manifest.container gets its own isolated VM, accessible
// via port-forwarded localhost:<hostPort>. The backend proxies /api/svc/<id>/* to it.

import http from 'node:http'

interface ContainerConfig {
  image: string
  port: number           // guest port
  startCmd?: string[]
  healthPath?: string
  memoryMib?: number
}

interface ServiceEntry {
  hostPort: number
  config: ContainerConfig
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  box: any               // SimpleBox — typed as any to survive missing native binding
}

// Host port range for service containers: 18000–18999
let nextHostPort = 18000
function allocatePort(): number { return nextHostPort++ }

let SimpleBoxClass: (new (opts: object) => unknown) | null = null
let serviceInitError: string | null = null
let serviceInitialized = false

function ensureServiceInit(): void {
  if (serviceInitialized) return
  serviceInitialized = true
  try {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const mod = require('@boxlite-ai/boxlite') as { SimpleBox: typeof SimpleBoxClass }
    SimpleBoxClass = mod.SimpleBox
    console.log('[svc] SimpleBox native binding loaded')
  } catch (err) {
    serviceInitError = err instanceof Error ? err.message : String(err)
    console.warn('[svc] native binding unavailable:', serviceInitError)
  }
}

export function isServiceAvailable(): boolean {
  ensureServiceInit()
  return SimpleBoxClass !== null
}

// Registry of running service boxes: moduleId → entry
const registry = new Map<string, ServiceEntry>()

function httpGet(url: string): Promise<number> {
  return new Promise((resolve) => {
    const req = http.get(url, (res) => { resolve(res.statusCode ?? 0) })
    req.on('error', () => resolve(0))
    req.setTimeout(2000, () => { req.destroy(); resolve(0) })
  })
}

async function waitHealthy(hostPort: number, healthPath: string, timeoutMs = 60_000): Promise<boolean> {
  const url = `http://127.0.0.1:${hostPort}${healthPath}`
  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    const code = await httpGet(url)
    if (code >= 200 && code < 300) return true
    await new Promise((r) => setTimeout(r, 1500))
  }
  return false
}

export async function startService(moduleId: string, cfg: ContainerConfig): Promise<{ ok: boolean; hostPort?: number; error?: string }> {
  ensureServiceInit()
  if (!SimpleBoxClass) return { ok: false, error: `BoxLite unavailable: ${serviceInitError}` }
  if (registry.has(moduleId)) return { ok: true, hostPort: registry.get(moduleId)!.hostPort }

  const hostPort = allocatePort()
  const healthPath = cfg.healthPath ?? '/health'

  const boxOpts = {
    image: cfg.image,
    memoryMib: cfg.memoryMib ?? 512,
    ports: [{ hostPort, guestPort: cfg.port }],
    autoRemove: true,
    name: `agent24-svc-${moduleId}`,
    reuseExisting: false,
  }

  let box: unknown
  try {
    box = new SimpleBoxClass(boxOpts)
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) }
  }

  // Start the service process in the background inside the container
  if (cfg.startCmd && cfg.startCmd.length > 0) {
    const [cmd, ...args] = cfg.startCmd
    const shell = `nohup ${[cmd, ...args].map(a => JSON.stringify(a)).join(' ')} > /tmp/svc.log 2>&1 &`
    try {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await (box as any).exec('sh', '-c', shell)
    } catch (err) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await (box as any).stop().catch(() => {/* best-effort */})
      return { ok: false, error: `Failed to start service: ${err instanceof Error ? err.message : err}` }
    }
  }

  const healthy = await waitHealthy(hostPort, healthPath)
  if (!healthy) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    await (box as any).stop().catch(() => {/* best-effort */})
    return { ok: false, error: `Service did not become healthy within 60s (checked ${healthPath})` }
  }

  registry.set(moduleId, { hostPort, config: cfg, box })
  console.log(`[svc] module ${moduleId} running on port ${hostPort}`)
  return { ok: true, hostPort }
}

export async function stopService(moduleId: string): Promise<void> {
  const entry = registry.get(moduleId)
  if (!entry) return
  registry.delete(moduleId)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  await (entry.box as any).stop().catch((err: unknown) => {
    console.warn(`[svc] stop ${moduleId}:`, err instanceof Error ? err.message : err)
  })
}

export async function stopAll(): Promise<void> {
  await Promise.all([...registry.keys()].map(stopService))
}

export function getHostPort(moduleId: string): number | null {
  return registry.get(moduleId)?.hostPort ?? null
}

// Proxy an HTTP request to the service container.
// Returns { status, body } or throws on connection error.
export async function proxyToService(
  moduleId: string,
  method: 'GET' | 'POST',
  subPath: string,
  query: string,
  body?: unknown,
): Promise<{ status: number; body: unknown }> {
  const entry = registry.get(moduleId)
  if (!entry) throw Object.assign(new Error(`Service ${moduleId} not running`), { statusCode: 503 })

  const url = `http://127.0.0.1:${entry.hostPort}${subPath}${query}`
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : undefined
    const opts: http.RequestOptions = {
      hostname: '127.0.0.1',
      port: entry.hostPort,
      path: subPath + query,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
      },
      timeout: 30_000,
    }
    const req = http.request(opts, (res) => {
      const chunks: Buffer[] = []
      res.on('data', (c: Buffer) => chunks.push(c))
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString()
        let parsed: unknown
        try { parsed = JSON.parse(raw) } catch { parsed = raw }
        resolve({ status: res.statusCode ?? 200, body: parsed })
      })
    })
    req.on('error', reject)
    req.on('timeout', () => { req.destroy(); reject(new Error(`Proxy timeout: ${url}`)) })
    if (payload) req.write(payload)
    req.end()
  })
}
