# Agent-Speaker Integration Plan

## What is agent-speaker?

agent-speaker is a Go CLI tool for **decentralized agent-to-agent communication** built
on the Nostr protocol. It extends the [nak](https://github.com/fiatjaf/nak) Nostr client
with agent-specific features:

- **Nostr-based messaging** — agents publish and query events on decentralized relays;
  no central server required.
- **zstd compression** — messages are compressed before publishing, reducing bandwidth
  and relay storage costs.
- **Relay management** — agents can run local relays and manage relay lists for
  availability and redundancy.
- **Timeline queries** — batch query and timeline views let an agent catch up on
  conversations it missed.
- **Go single-binary** — compiles to one binary (`agent-speaker`), easy to embed in
  Docker images.

Core commands:

| Command | Purpose |
|---------|---------|
| `agent msg` | Send a compressed message to another agent (by pubkey) |
| `agent query` | Batch query events by filter |
| `agent timeline` | View chronological message timeline |
| `agent relay` | Add/remove/list local relays |
| `key generate` | Generate Nostr keypair |

---

## Integration Approach: MCP Tool Server

We wrap agent-speaker as an **MCP (Model Context Protocol) tool server** so that
Claude Code (and any MCP-compatible host) can call it without shelling out manually.

### Architecture

```
Claude Code  ──MCP──▶  agent-speaker-mcp  ──exec──▶  agent-speaker binary
                        (Python/Node wrapper)          (Go CLI in vendor/)
```

The MCP server is a thin process that:
1. Starts as a stdio MCP server (spawned by Claude Code).
2. Translates MCP tool calls into `agent-speaker` CLI invocations.
3. Parses CLI output (JSON/text) and returns structured MCP responses.

### Why MCP?

- Claude Code already supports MCP servers — zero host-side changes.
- Other agents (Cursor, Windsurf, any MCP client) get the same capability.
- Tool schemas are self-describing; the model sees typed parameters.

---

## MCP Tools to Expose

### `send_message`

Send a compressed Nostr message to another agent.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `recipient_pubkey` | string | yes | Nostr public key of the target agent |
| `content` | string | yes | Message body (will be zstd-compressed) |
| `relays` | string[] | no | Override relay list for this send |

### `query_messages`

Query messages by filter criteria.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `authors` | string[] | no | Filter by sender pubkeys |
| `kinds` | int[] | no | Nostr event kinds |
| `since` | string | no | ISO timestamp lower bound |
| `limit` | int | no | Max results (default 50) |

### `timeline`

Retrieve a chronological timeline of recent agent messages.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `limit` | int | no | Number of events (default 20) |
| `since` | string | no | ISO timestamp lower bound |

### `manage_relays`

Add, remove, or list configured Nostr relays.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | enum | yes | `add`, `remove`, or `list` |
| `url` | string | no | Relay WebSocket URL (required for add/remove) |

---

## How It Fits Agent24

### Proactive Cross-Agent Communication

Today, agents in the AutoAgent/Agent24 ecosystem operate in isolation — each agent
runs its benchmark tasks without awareness of others. agent-speaker enables:

- **Broadcasting discoveries** — when an agent finds a successful harness improvement,
  it can publish the result so peer agents can adopt or build on it.
- **Requesting help** — an agent stuck on a task category can query peers for strategies.
- **Shared blocklist** — agents can publish known-bad approaches to avoid redundant work.

### Organization-Level Coordination (`/org-sync`)

The existing `/org-sync` skill shares context via filesystem (`~/.claude/org/`).
agent-speaker extends this to **cross-machine and cross-network** coordination:

- Org blueprints and progress updates published to a shared relay.
- Remote team members' agents subscribe and stay synchronized.
- No VPN or shared filesystem required — just Nostr relay URLs.

### Integration with `/evolve`

The `/evolve` self-improvement cycle can optionally broadcast each iteration's score
to a Nostr channel, creating a public leaderboard of harness variants. Other agents
(or humans) can subscribe and cherry-pick winning strategies.

---

## Implementation Steps

1. **Build agent-speaker binary** — `cd vendor/agent-speaker && make build`
2. **Create MCP server wrapper** — `tools/agent-speaker-mcp/server.py` using the
   `mcp` Python SDK; each tool calls the binary via `subprocess`.
3. **Add to `.claude/settings.json`** — register the MCP server so Claude Code
   auto-starts it.
4. **Write tests** — integration tests that spin up a local relay and verify
   send/query round-trip.
5. **Document in skills** — add `/speak` skill that wraps common messaging patterns.

---

## Open Questions

- **Key management** — where to store the agent's Nostr secret key securely
  (env var, keychain, encrypted file).
- **Relay selection** — default public relays vs. private org relay.
- **Message schema** — define a Nostr event kind or tag convention for agent messages
  to distinguish them from human Nostr traffic.
