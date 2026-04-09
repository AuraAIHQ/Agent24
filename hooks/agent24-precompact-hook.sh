#!/usr/bin/env bash
# Agent24 PreCompact Hook
# Fires RIGHT BEFORE Claude Code compresses conversation context.
# Always blocks — forces the AI to save everything important before
# context is lost to compression.
#
# Install: added to ~/.claude/settings.json by install.sh
# Based on MemPalace's precompact hook pattern

set -euo pipefail

STATE_DIR="${HOME}/.claude/hook_state"
mkdir -p "$STATE_DIR"

# Log the compaction event
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) precompact triggered" >> "${STATE_DIR}/hook.log"

# Always block — compaction means we're about to lose context
cat <<'HOOKEOF'
{
  "decision": "block",
  "reason": "EMERGENCY SAVE (Agent24). Context is about to be compressed. Before proceeding, save ALL important context from this session:\n\n1. Current task status and progress\n2. Key decisions and their reasoning\n3. Discoveries, insights, or strategy outcomes\n4. Any unfinished work that needs to be resumed\n5. Important file paths, function names, or references\n\nWrite to memory files using standard front-matter format. Update MEMORY.md index. Mark importance: 5 for anything critical to resuming work.\n\nAfter saving, compaction may proceed."
}
HOOKEOF
