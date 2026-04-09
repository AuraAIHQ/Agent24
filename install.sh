#!/usr/bin/env bash
set -euo pipefail

# Agent24 Installer
# Installs skills + org-context framework to ~/.claude/ for global use

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_DIR}/skills"
ORG_DIR="${CLAUDE_DIR}/org"
BACKUP_DIR="${CLAUDE_DIR}/backups/agent24-$(date +%Y%m%d%H%M%S)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "  Agent24 Installer"
echo "  Self-evolving agent for Claude Code"
echo "============================================"
echo ""

# --- Install Skills (with backup) ---
echo -e "${GREEN}[1/3] Installing skills...${NC}"

for skill_dir in "${SCRIPT_DIR}/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    target="${SKILLS_DIR}/${skill_name}"

    if [ -d "$target" ]; then
        # Backup entire existing skill directory before overwrite
        mkdir -p "${BACKUP_DIR}/skills/"
        cp -r "$target" "${BACKUP_DIR}/skills/${skill_name}"
        echo -e "  ${YELLOW}↻${NC} Updating: ${skill_name} (backup in backups/)"
    else
        echo -e "  ${GREEN}+${NC} Installing: ${skill_name}"
        mkdir -p "$target"
    fi
    # Copy all files including dotfiles
    cp -r "${skill_dir}". "$target/" 2>/dev/null || cp -r "${skill_dir}"* "$target/"
done

# --- Install Hooks ---
echo -e "${GREEN}[2/5] Installing hooks...${NC}"

HOOKS_TARGET="${CLAUDE_DIR}/hooks"
mkdir -p "$HOOKS_TARGET"

for hook_file in "${SCRIPT_DIR}/hooks"/*.sh; do
    [ -f "$hook_file" ] || continue
    hook_name=$(basename "$hook_file")
    cp "$hook_file" "${HOOKS_TARGET}/${hook_name}"
    chmod +x "${HOOKS_TARGET}/${hook_name}"
    echo -e "  ${GREEN}+${NC} Installed: ${hook_name}"
done

# --- Install Agent Config (template only, don't overwrite) ---
echo -e "${GREEN}[3/5] Installing agent config...${NC}"

if [ ! -f "${CLAUDE_DIR}/agent-config.yaml" ]; then
    cp "${SCRIPT_DIR}/agent-config.yaml" "${CLAUDE_DIR}/agent-config.yaml"
    echo -e "  ${GREEN}+${NC} Created: ~/.claude/agent-config.yaml"
else
    echo -e "  ${YELLOW}~${NC} Skipped: ~/.claude/agent-config.yaml (already exists)"
fi

# --- Initialize Org Context (directory only, don't overwrite) ---
echo -e "${GREEN}[4/5] Preparing org context...${NC}"

if [ ! -d "$ORG_DIR" ]; then
    mkdir -p "$ORG_DIR"
    echo -e "  ${GREEN}+${NC} Created: ~/.claude/org/"
    echo -e "  ${YELLOW}→${NC} Run ${GREEN}/org-sync init${NC} in Claude Code to set up your org blueprint"
else
    echo -e "  ${YELLOW}~${NC} Skipped: ~/.claude/org/ (already exists)"
fi

# --- Configure Hook Settings ---
echo -e "${GREEN}[5/5] Configuring hooks...${NC}"

SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
SAVE_HOOK="${HOOKS_TARGET}/agent24-save-hook.sh"
PRECOMPACT_HOOK="${HOOKS_TARGET}/agent24-precompact-hook.sh"

# Remove any existing agent24 hooks before adding fresh ones (prevents duplicates)
if [ -f "$SETTINGS_FILE" ] && grep -q "agent24-" "$SETTINGS_FILE" 2>/dev/null; then
    echo -e "  ${YELLOW}↻${NC} Removing existing agent24 hooks (will re-add fresh)"
    SETTINGS_PATH="$SETTINGS_FILE" python3 -c '
import json, os
sf = os.environ["SETTINGS_PATH"]
with open(sf) as f:
    settings = json.load(f)
hooks = settings.get("hooks", {})
for event in ["Stop", "PreCompact"]:
    if event in hooks:
        cleaned = []
        for entry in hooks[event]:
            # Filter out only agent24 commands, keep other commands in same entry
            inner = entry.get("hooks", [])
            inner = [h for h in inner if "agent24-" not in str(h.get("command", ""))]
            if inner:
                entry["hooks"] = inner
                cleaned.append(entry)
        if cleaned:
            hooks[event] = cleaned
        else:
            del hooks[event]
with open(sf, "w") as f:
    json.dump(settings, f, indent=2)
' 2>/dev/null || true
fi

if [ -f "$SETTINGS_FILE" ]; then
    # Backup existing settings
    mkdir -p "${BACKUP_DIR}"
    cp "$SETTINGS_FILE" "${BACKUP_DIR}/settings.json"
    echo -e "  ${YELLOW}↻${NC} Backed up existing settings.json"
fi

# Add fresh hooks (atomic write via temp file + rename)
SAVE_HOOK_PATH="$SAVE_HOOK" PRECOMPACT_HOOK_PATH="$PRECOMPACT_HOOK" \
SETTINGS_PATH="$SETTINGS_FILE" \
python3 -c '
import json, os, tempfile

sf = os.environ["SETTINGS_PATH"]
save_hook = os.environ["SAVE_HOOK_PATH"]
precompact_hook = os.environ["PRECOMPACT_HOOK_PATH"]

settings = {}
if os.path.exists(sf):
    with open(sf) as f:
        settings = json.load(f)

hooks = settings.setdefault("hooks", {})
stop_hooks = hooks.setdefault("Stop", [])
stop_hooks.append({"matcher": "", "hooks": [{"type": "command", "command": save_hook}]})
precompact_hooks = hooks.setdefault("PreCompact", [])
precompact_hooks.append({"matcher": "", "hooks": [{"type": "command", "command": precompact_hook}]})

# Atomic write: temp file + rename
tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(sf) or ".")
with os.fdopen(tmp_fd, "w") as f:
    json.dump(settings, f, indent=2)
os.replace(tmp_path, sf)
' 2>/dev/null && echo -e "  ${GREEN}+${NC} Configured Stop + PreCompact hooks in settings.json" \
              || echo -e "  ${YELLOW}!${NC} Could not configure hooks (Python 3 required). Add manually."

# Clean up empty backup dir
[ -d "$BACKUP_DIR" ] || true
find "${BACKUP_DIR}" -type d -empty -delete 2>/dev/null || true

# --- Done ---
echo ""
echo "============================================"
echo -e "  ${GREEN}Done!${NC}"
echo ""
echo "  Installed skills:"
for skill_dir in "${SCRIPT_DIR}/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    echo "    /$(basename "$skill_dir")"
done
echo ""
echo "  Usage:"
echo "    cd any-project/"
echo "    claude"
echo "    > /init                  # first time: guided onboarding"
echo "    > /evolve <task>         # run a self-evolving cycle"
echo "    > /evaluate [target]     # evaluate code quality"
echo "    > /org-sync              # check org status"
echo ""
echo "  Auto-save hooks: active (every 15 messages + before compaction)"
echo ""
echo "  Config: ~/.claude/agent-config.yaml"
echo "  Org:    ~/.claude/org/"
echo "  Hooks:  ~/.claude/hooks/"
echo "============================================"
