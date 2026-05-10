import type { CapabilityContext, ModuleManifest } from '../types'

export interface SimpleRouter {
  get(path: string, handler: RouteHandler): void
  post(path: string, handler: RouteHandler): void
}

export interface RouteContext {
  params: Record<string, string>
  query: Record<string, string>
  body: unknown
}

export type RouteHandler = (ctx: RouteContext) => Promise<unknown> | unknown

/**
 * Base interface for all capability modules.
 *
 * UI module (manifest.type = 'ui' | 'hybrid'):
 *   - Ships a React component loaded lazily by the renderer
 *   - Component communicates with daemon via window.agent24.backendProxy()
 *   - Declares navItem in manifest → shell injects it into sidebar automatically
 *
 * Headless module (manifest.type = 'headless'):
 *   - Registers daemon-side routes only, no renderer component
 *   - Results surface through chat bubbles or notifications in our generic UI
 *   - May spawn its own subprocess and proxy calls to its REST API
 */
export interface CapabilityModule {
  manifest: ModuleManifest
  register(router: SimpleRouter, ctx: CapabilityContext): void
}
