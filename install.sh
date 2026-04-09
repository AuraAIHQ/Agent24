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

# --- Install Agent Config (template only, don't overwrite) ---
echo -e "${GREEN}[2/3] Installing agent config...${NC}"

if [ ! -f "${CLAUDE_DIR}/agent-config.yaml" ]; then
    cp "${SCRIPT_DIR}/agent-config.yaml" "${CLAUDE_DIR}/agent-config.yaml"
    echo -e "  ${GREEN}+${NC} Created: ~/.claude/agent-config.yaml"
else
    echo -e "  ${YELLOW}~${NC} Skipped: ~/.claude/agent-config.yaml (already exists)"
fi

# --- Initialize Org Context (directory only, don't overwrite) ---
echo -e "${GREEN}[3/3] Preparing org context...${NC}"

if [ ! -d "$ORG_DIR" ]; then
    mkdir -p "$ORG_DIR"
    echo -e "  ${GREEN}+${NC} Created: ~/.claude/org/"
    echo -e "  ${YELLOW}→${NC} Run ${GREEN}/org-sync init${NC} in Claude Code to set up your org blueprint"
else
    echo -e "  ${YELLOW}~${NC} Skipped: ~/.claude/org/ (already exists)"
fi

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
echo "    > /evolve <task>        # run a self-evolving cycle"
echo "    > /evaluate [target]    # evaluate code quality"
echo "    > /org-sync init        # set up org context"
echo "    > /org-sync             # check org status"
echo ""
echo "  Config: ~/.claude/agent-config.yaml"
echo "  Org:    ~/.claude/org/"
echo "============================================"
