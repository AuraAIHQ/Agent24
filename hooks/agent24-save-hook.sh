#!/usr/bin/env bash
# Agent24 Save Hook
# Triggers on Claude Code "Stop" event. Every N human messages,
# blocks the stop and asks the AI to save important context to memory.
#
# Install: added to ~/.claude/settings.json by install.sh
# Based on MemPalace's save hook pattern (idempotent, no infinite loops)

# No set -e: must always output valid JSON even on errors
set -uo pipefail

# Check python3 is available
if ! command -v python3 &>/dev/null; then
    echo "WARNING: python3 not found — Agent24 auto-save disabled" >&2
    echo '{"decision": "allow"}'
    exit 0
fi

SAVE_INTERVAL="${AGENT24_SAVE_INTERVAL:-15}"
STATE_DIR="${HOME}/.claude/hook_state"
STATE_FILE="${STATE_DIR}/agent24_save.json"
LOCK_FILE="${STATE_DIR}/agent24_save.lock"

mkdir -p "$STATE_DIR" 2>/dev/null || true

# Read input, pass to Python via stdin. No shell var interpolation into code.
INPUT=$(cat)

printf '%s' "$INPUT" | \
SAVE_INTERVAL="$SAVE_INTERVAL" STATE_FILE="$STATE_FILE" LOCK_FILE="$LOCK_FILE" \
python3 -c '
import json, sys, os, tempfile, fcntl

ALLOW = json.dumps({"decision": "allow"})

try:
    save_interval = max(1, int(os.environ.get("SAVE_INTERVAL", "15")))
except (ValueError, TypeError):
    save_interval = 15
state_file = os.environ.get("STATE_FILE", "")
lock_file = os.environ.get("LOCK_FILE", "")

try:
    data = json.load(sys.stdin)
except Exception:
    print(ALLOW)
    sys.exit(0)

try:
    session_id = str(data.get("session_id", "unknown"))
    stop_hook_active = data.get("stop_hook_active", False)
    if isinstance(stop_hook_active, str):
        stop_hook_active = stop_hook_active.lower() in ("true", "1", "yes")
    transcript_path = str(data.get("transcript_path", ""))

    # Re-entry guard
    if stop_hook_active:
        print(ALLOW)
        sys.exit(0)

    # Count human messages
    msg_count = 0
    if transcript_path and os.path.isfile(transcript_path):
        try:
            with open(transcript_path) as f:
                for line in f:
                    try:
                        if json.loads(line.strip()).get("role") == "human":
                            msg_count += 1
                    except Exception:
                        pass
        except Exception:
            pass

    # Locked state read + write
    last_saved = 0
    should_block = False

    if lock_file and state_file:
        lock_fd = open(lock_file, "w")
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX)

            # Read state
            state = {}
            if os.path.isfile(state_file):
                try:
                    with open(state_file) as f:
                        state = json.load(f)
                except Exception:
                    state = {}
            last_saved = state.get(session_id, 0)

            if msg_count - last_saved >= save_interval:
                should_block = True
                state[session_id] = msg_count
                # Atomic write
                d = os.path.dirname(state_file) or "."
                tmp_fd, tmp_path = tempfile.mkstemp(dir=d)
                try:
                    with os.fdopen(tmp_fd, "w") as f:
                        json.dump(state, f)
                    os.replace(tmp_path, state_file)
                except Exception:
                    try: os.unlink(tmp_path)
                    except Exception: pass
        finally:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            lock_fd.close()

    if should_block:
        print(json.dumps({
            "decision": "block",
            "reason": "AUTO-SAVE checkpoint (Agent24). Before stopping, please save important context from this session:\\n\\n1. Key decisions made\\n2. Important discoveries or insights\\n3. Strategy outcomes (what worked, what failed)\\n4. Any context that would be lost after this session\\n\\nWrite to memory files in ~/.claude/memory/ or .claude/memory/ using the standard front-matter format (name/description/type/created/valid_from/importance). Then update MEMORY.md index.\\n\\nAfter saving, you may stop."
        }))
    else:
        print(ALLOW)

except Exception:
    # Safety net: never fail to output a decision
    print(ALLOW)
'
