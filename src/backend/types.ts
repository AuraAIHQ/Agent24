import type { LLMGateway } from './llm-gateway'

// ── LLM ──────────────────────────────────────────────────────────────────────

export interface ChatMessage {
  role: 'user' | 'assistant' | 'system'
  content: string
}

export interface LLMRequest {
  model?: string
  messages: ChatMessage[]
  stream?: boolean
}

export type LLMProvider = 'omlx' | 'ollama' | 'claude' | 'openai'

export interface LLMUsage {
  tokens: number
  model: string
  provider: LLMProvider
  moduleId: string
  timestamp: number
}

// ── Capability Module ─────────────────────────────────────────────────────────

export interface CapabilityContext {
  llm: LLMGateway
  moduleId: string
}

/**
 * type 'ui'       : ships a React component; shell renders it in the main area via sidebar nav.
 * type 'headless' : daemon-side routes only; results surface through chat / notifications.
 * type 'hybrid'   : has both a config UI page AND background capabilities.
 */
export type ModuleType = 'ui' | 'headless' | 'hybrid'

export type Permission =
  | 'llm'         // call LLMGateway
  | 'memory'      // read/write memory layer
  | 'network'     // outbound HTTP
  | 'filesystem'  // read/write local files
  | 'wechat'      // WeChat bridge
  | 'nostr'       // Nostr relay

export interface ModuleManifest {
  id: string                  // e.g. '@auraaihq/publish-blog'
  version: string
  name: string
  description: string
  type: ModuleType
  permissions: Permission[]
  navItem?: {                 // UI/hybrid only — injected into sidebar
    icon: string
    label: string
    route: string
  }
}
