#!/usr/bin/env bash
# Remove the Hudson symlinks from claude-code and cursor-agent.
# Leaves the vault (including memory files) and the HUDSON_VAULT / ZK_VAULT
# env var exports in ~/.zshrc.local untouched.
set -euo pipefail

unlink_if_symlink() {
  local dst="$1"
  if [ -L "$dst" ]; then
    rm -f "$dst"
    echo "✓ Removed $dst"
  elif [ -e "$dst" ]; then
    echo "⚠ $dst exists but is not a symlink — leaving it alone"
  else
    echo "· $dst not present"
  fi
}

echo "→ Uninstalling Hudson skill wiring"
unlink_if_symlink "$HOME/.claude/skills/hudson"
unlink_if_symlink "$HOME/.claude/commands/hudson.md"
unlink_if_symlink "$HOME/.cursor/skills/hudson"
echo "✓ Hudson uninstalled. Vault and HUDSON_VAULT / ZK_VAULT exports untouched."
