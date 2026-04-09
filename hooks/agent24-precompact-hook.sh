#!/usr/bin/env bash
# Agent24 PreCompact Hook
# Fires RIGHT BEFORE Claude Code compresses conversation context.
# Blocks ONCE to force the AI to save important context, then allows.
#
# Install: added to ~/.claude/settings.json by install.sh
# Based on MemPalace's precompact hook pattern

set -uo pipefail  # no -e: must always output valid JSON

STATE_DIR="${HOME}/.claude/hook_state"
LOG_FILE="${STATE_DIR}/hook.log"
MAX_LOG_LINES=500

mkdir -p "$STATE_DIR" 2>/dev/null || true

# Rotate log if too large
if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)" -gt "$MAX_LOG_LINES" ]; then
    tail -n 250 "$LOG_FILE" > "${LOG_FILE}.tmp" 2>/dev/null && mv "${LOG_FILE}.tmp" "$LOG_FILE" 2>/dev/null || true
fi

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) precompact triggered" >> "$LOG_FILE" 2>/dev/null || true

# Read input for re-entry guard
INPUT=$(cat)
STOP_HOOK_ACTIVE="false"
if command -v python3 &>/dev/null; then
    STOP_HOOK_ACTIVE=$(printf '%s' "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(str(d.get('stop_hook_active', False)).lower())" 2>/dev/null || echo "false")
fi

# Extract session_id and hash it for safe filenames (no path traversal)
SID_HASH="unknown"
if command -v python3 &>/dev/null; then
    SID_HASH=$(printf '%s' "$INPUT" | python3 -c "import sys,json,hashlib; sid=json.load(sys.stdin).get('session_id','unknown'); print(hashlib.sha256(sid.encode()).hexdigest()[:16])" 2>/dev/null || echo "unknown")
fi

PRECOMPACT_FLAG="${STATE_DIR}/precompact_blocked_${SID_HASH}"

# Clean up legacy file-based flag from previous versions (upgrade compat)
if [ -e "$PRECOMPACT_FLAG" ] && [ ! -d "$PRECOMPACT_FLAG" ]; then
    rm -f "$PRECOMPACT_FLAG" 2>/dev/null || true
fi

# Re-entry guard: if AI already saved, allow compaction
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    rmdir "$PRECOMPACT_FLAG" 2>/dev/null || true
    echo '{"decision": "allow"}'
    exit 0
fi

# Atomic flag check using mkdir (POSIX-portable, no flock needed).
# mkdir is atomic: only one concurrent caller succeeds; others get EEXIST.
# If mkdir succeeds → first time → block. If it fails → already blocked → allow.
if mkdir "$PRECOMPACT_FLAG" 2>/dev/null; then
    # First invocation for this session — will block below
    :
else
    # Already blocked once — clean up and allow
    rmdir "$PRECOMPACT_FLAG" 2>/dev/null || true
    echo '{"decision": "allow"}'
    exit 0
fi

# Block once — force save before compaction
cat <<'HOOKEOF'
{
  "decision": "block",
  "reason": "EMERGENCY SAVE (Agent24). Context is about to be compressed. Before proceeding, save ALL important context from this session:\n\n1. Current task status and progress\n2. Key decisions and their reasoning\n3. Discoveries, insights, or strategy outcomes\n4. Any unfinished work that needs to be resumed\n5. Important file paths, function names, or references\n\nWrite to memory files using standard front-matter format. Update MEMORY.md index. Mark importance: 5 for anything critical to resuming work.\n\nAfter saving, compaction may proceed."
}
HOOKEOF
