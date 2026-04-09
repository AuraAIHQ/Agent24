#!/usr/bin/env bash
# Agent24 Save Hook
# Triggers on Claude Code "Stop" event. Every N human messages,
# blocks the stop and asks the AI to save important context to memory.
#
# Install: added to ~/.claude/settings.json by install.sh
# Based on MemPalace's save hook pattern (idempotent, no infinite loops)

set -euo pipefail

SAVE_INTERVAL="${AGENT24_SAVE_INTERVAL:-15}"
STATE_DIR="${HOME}/.claude/hook_state"
STATE_FILE="${STATE_DIR}/agent24_save.json"

mkdir -p "$STATE_DIR"

# Read input from Claude Code
INPUT=$(cat)

# Extract session info
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown'))" 2>/dev/null || echo "unknown")
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(str(d.get('stop_hook_active', False)).lower())" 2>/dev/null || echo "false")
TRANSCRIPT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null || echo "")

# If this is a re-entry after we already blocked, allow the stop
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Count human messages in transcript
MSG_COUNT=0
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
    MSG_COUNT=$(python3 -c "
import json, sys
count = 0
with open('$TRANSCRIPT') as f:
    for line in f:
        try:
            msg = json.loads(line.strip())
            if msg.get('role') == 'human':
                count += 1
        except: pass
print(count)
" 2>/dev/null || echo "0")
fi

# Read last saved count for this session
LAST_SAVED=0
if [ -f "$STATE_FILE" ]; then
    LAST_SAVED=$(python3 -c "
import json
with open('$STATE_FILE') as f:
    d = json.load(f)
print(d.get('$SESSION_ID', 0))
" 2>/dev/null || echo "0")
fi

# Check if we've crossed a save interval boundary
MESSAGES_SINCE_SAVE=$((MSG_COUNT - LAST_SAVED))

if [ "$MESSAGES_SINCE_SAVE" -ge "$SAVE_INTERVAL" ]; then
    # Update state
    python3 -c "
import json, os
state = {}
sf = '$STATE_FILE'
if os.path.exists(sf):
    with open(sf) as f:
        state = json.load(f)
state['$SESSION_ID'] = $MSG_COUNT
with open(sf, 'w') as f:
    json.dump(state, f)
" 2>/dev/null || true

    # Block the stop and ask AI to save
    cat <<'HOOKEOF'
{
  "decision": "block",
  "reason": "AUTO-SAVE checkpoint (Agent24). Before stopping, please save important context from this session:\n\n1. Key decisions made\n2. Important discoveries or insights\n3. Strategy outcomes (what worked, what failed)\n4. Any context that would be lost after this session\n\nWrite to memory files in ~/.claude/memory/ or .claude/memory/ using the standard front-matter format (name/description/type/created/valid_from/importance). Then update MEMORY.md index.\n\nAfter saving, you may stop."
}
HOOKEOF
else
    echo '{"decision": "allow"}'
fi
