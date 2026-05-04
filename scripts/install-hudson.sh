#!/usr/bin/env bash
# Wire the Hudson agent skill into claude-code and cursor-agent.
# Canonical source: $HUDSON_VAULT/.cursor/skills/hudson/ (inside the vault).
#
# Vault path resolution (matches `link-vault-skills.sh` and the Hudson
# Obsidian plugin's backend):
#   1. $HUDSON_VAULT — the canonical env var, standardised across all
#      Hudson tooling.
#   2. $ZK_VAULT     — legacy fallback for users who set this before
#      Hudson existed; warns and recommends migration.
#   3. ~/code/zettelkasten — final default.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUDSON_VAULT_DEFAULT="$HOME/code/zettelkasten"

if [ -n "${HUDSON_VAULT:-}" ]; then
  VAULT="$HUDSON_VAULT"
  VAULT_SRC="HUDSON_VAULT"
elif [ -n "${ZK_VAULT:-}" ]; then
  VAULT="$ZK_VAULT"
  VAULT_SRC="ZK_VAULT (deprecated — set HUDSON_VAULT instead)"
  echo "⚠  Using \$ZK_VAULT as the vault path. This env var is deprecated."
  echo "   Migrate with:  export HUDSON_VAULT=\"\$ZK_VAULT\""
  echo
else
  VAULT="$HUDSON_VAULT_DEFAULT"
  VAULT_SRC="default ($HUDSON_VAULT_DEFAULT)"
fi

SKILL_SRC="$VAULT/.cursor/skills/hudson"
# Source of truth for the slash-command wrapper lives in the vault alongside
# the skill, so the Hudson Obsidian plugin and the terminal-global /hudson
# share a single canonical file.
CMD_SRC="$VAULT/.claude/commands/hudson.md"

timestamp() { date +"%Y%m%d_%H%M%S"; }

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="${dst}.bak.$(timestamp)"
    echo "→ Backing up $dst → $backup"
    mv "$dst" "$backup"
  elif [ -L "$dst" ]; then
    rm -f "$dst"
  fi
  ln -sfn "$src" "$dst"
  echo "✓ $dst → $src"
}

echo "→ Installing Hudson skill wiring"
echo "   Vault: $VAULT"
echo "   Source: $VAULT_SRC"

if [ ! -d "$SKILL_SRC" ]; then
  echo "✗ Skill source not found at $SKILL_SRC"
  echo "   Clone the vault there, or set HUDSON_VAULT to its real location."
  exit 1
fi

if [ ! -f "$CMD_SRC" ]; then
  echo "✗ Vault command source missing at $CMD_SRC"
  echo "   Expected the /hudson wrapper at <vault>/.claude/commands/hudson.md"
  exit 1
fi

# 1. Claude Code skill (description-triggered)
link "$SKILL_SRC" "$HOME/.claude/skills/hudson"

# 2. Claude Code slash command (/hudson)
link "$CMD_SRC" "$HOME/.claude/commands/hudson.md"

# 3. Cursor Agent skill (global, any workspace)
link "$SKILL_SRC" "$HOME/.cursor/skills/hudson"

# 4. Ensure HUDSON_VAULT + HUDSON_CALENDAR_DIR are exported from ~/.zshrc.local
ZSHRC_LOCAL="$HOME/.zshrc.local"
touch "$ZSHRC_LOCAL"

if ! grep -q '^export HUDSON_VAULT=' "$ZSHRC_LOCAL"; then
  {
    echo ""
    echo "# Vault root (used by the Hudson skill, plugin backend, and link-vault-skills.sh)"
    echo "export HUDSON_VAULT=\"$VAULT\""
  } >> "$ZSHRC_LOCAL"
  echo "✓ Appended HUDSON_VAULT export to $ZSHRC_LOCAL"
else
  echo "· HUDSON_VAULT already exported in $ZSHRC_LOCAL"
fi

# Backward-compat: if ZK_VAULT is exported but HUDSON_VAULT was just added,
# keep ZK_VAULT in sync so any other Zettelkasten tooling that reads it
# continues to work without surprises.
if grep -q '^export ZK_VAULT=' "$ZSHRC_LOCAL"; then
  echo "· ZK_VAULT export retained in $ZSHRC_LOCAL for backward compat"
fi

if ! grep -q '^export HUDSON_CALENDAR_DIR=' "$ZSHRC_LOCAL"; then
  {
    echo ""
    echo "# Outlook calendar export (populated by a Power Automate scheduled flow)"
    echo "export HUDSON_CALENDAR_DIR=\"\$HOME/Library/CloudStorage/OneDrive-Paysafe/meeting_export\""
  } >> "$ZSHRC_LOCAL"
  echo "✓ Appended HUDSON_CALENDAR_DIR export to $ZSHRC_LOCAL"
else
  echo "· HUDSON_CALENDAR_DIR already exported in $ZSHRC_LOCAL"
fi

echo "✓ Hudson installed. Open a new shell (or 'exec zsh') to pick up HUDSON_VAULT."
