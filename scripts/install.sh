#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES="$REPO_DIR"

have() { command -v "$1" >/dev/null 2>&1; }

timestamp() { date +"%Y%m%d_%H%M%S"; }

backup_and_link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local backup="${dst}.bak.$(timestamp)"
    echo "→ Backing up $dst → $backup"
    mv "$dst" "$backup"
  elif [ -L "$dst" ]; then
    echo "→ Removing existing symlink $dst"
    rm -f "$dst"
  fi
  ln -sfn "$src" "$dst"
  echo "✓ Linked $dst → $src"
}

echo "→ Ensuring Homebrew..."
if ! have brew; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
else
  eval "$(brew shellenv)"
fi

echo "→ Installing packages from Brewfile..."
brew bundle --file="$DOTFILES/Brewfile"

echo "→ Initializing/updating submodules..."
git -C "$DOTFILES" submodule update --init --recursive

# --- Helix editor config ---
HELIX_HOME="$HOME/.config/helix"
HELIX_REPO="$DOTFILES/helix"

mkdir -p "$(dirname "$HELIX_HOME")"
backup_and_link "$HELIX_REPO" "$HELIX_HOME"

# --- Zellij config ---
ZELLIJ_HOME="$HOME/.config/zellij"
ZELLIJ_REPO="$DOTFILES/zellij"

mkdir -p "$(dirname "$ZELLIJ_HOME")"
backup_and_link "$ZELLIJ_REPO" "$ZELLIJ_HOME"

# --- Git config (delta, aliases) ---
# Migrate existing user settings to .gitconfig.local before replacing
if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ] && [ ! -f "$HOME/.gitconfig.local" ]; then
  echo "→ Migrating existing git user settings to ~/.gitconfig.local"
  {
    echo "# Migrated from existing ~/.gitconfig on $(date)"
    echo ""
    # Extract [user] section
    if git config --global user.name >/dev/null 2>&1; then
      echo "[user]"
      git config --global user.name >/dev/null 2>&1 && echo "    name = $(git config --global user.name)"
      git config --global user.email >/dev/null 2>&1 && echo "    email = $(git config --global user.email)"
      git config --global user.signingkey >/dev/null 2>&1 && echo "    signingkey = $(git config --global user.signingkey)"
      echo ""
    fi
    # Extract [credential] section if present
    if git config --global credential.helper >/dev/null 2>&1; then
      echo "[credential]"
      echo "    helper = $(git config --global credential.helper)"
      echo ""
    fi
    # Extract [commit] section if present (for GPG signing)
    if git config --global commit.gpgsign >/dev/null 2>&1; then
      echo "[commit]"
      echo "    gpgsign = $(git config --global commit.gpgsign)"
      echo ""
    fi
  } > "$HOME/.gitconfig.local"
  echo "✓ Created ~/.gitconfig.local with your existing settings"
fi

backup_and_link "$DOTFILES/git/config" "$HOME/.gitconfig"
if [ ! -f "$HOME/.gitconfig.local" ]; then
  echo "   Note: Add machine-specific git settings (name, email) to ~/.gitconfig.local"
fi

echo "→ Installing fzf keybindings/completions..."
"$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc

echo "→ Linking dotfiles (with backups if needed)..."
backup_and_link "$DOTFILES/zsh/.zshenv" "$HOME/.zshenv"
backup_and_link "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
backup_and_link "$DOTFILES/p10k/.p10k.zsh" "$HOME/.p10k.zsh"

# Link iTerm2 Dynamic Profile
ITERM_PROFILE="$DOTFILES/iterm2/Dotfiles-MinimalP10k.json"
ITERM_DYNAMIC_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
mkdir -p "$ITERM_DYNAMIC_DIR"
ln -sfn "$ITERM_PROFILE" "$ITERM_DYNAMIC_DIR/Dotfiles-MinimalP10k.json"
echo "✓ Linked iTerm2 profile"

# Make zsh default shell
if [ "$SHELL" != "$(command -v zsh)" ]; then
  echo "→ Setting zsh as default shell (you may be prompted)..."
  chsh -s "$(command -v zsh)" || echo "   Run manually: chsh -s $(command -v zsh)"
fi

echo "→ Installing MCP servers..."
if have uv; then
  uv tool install mcp-obsidian
  echo "✓ Installed mcp-obsidian"
else
  echo "   uv not found, will be installed via Homebrew"
fi

echo "→ Installing GitHub MCP server..."
if have go; then
  echo "   Installing github-mcp-server via go..."
  go install github.com/github/github-mcp-server/cmd/github-mcp-server@latest
  echo "✓ Installed github-mcp-server"
else
  echo "   go not found, GitHub MCP server will use Docker fallback"
fi

echo "→ Creating MCP wrapper scripts..."
mkdir -p ~/.mcp-wrappers

# Clean up old todoist wrapper (now uses official hosted MCP with OAuth)
if [ -f ~/.mcp-wrappers/todoist-wrapper.sh ]; then
  rm -f ~/.mcp-wrappers/todoist-wrapper.sh
  echo "✓ Removed obsolete todoist-wrapper.sh (now using official hosted MCP)"
fi

# Obsidian wrapper
cat > ~/.mcp-wrappers/obsidian-wrapper.sh << 'EOF'
#!/bin/bash
if [ -f ~/.env.mcp ]; then
    source ~/.env.mcp
fi
exec /opt/homebrew/bin/uvx mcp-obsidian
EOF

# GitHub wrapper
cat > ~/.mcp-wrappers/github-wrapper.sh << 'EOF'
#!/bin/bash
if [ -f ~/.env.mcp ]; then
    source ~/.env.mcp
fi
exec ~/go/bin/github-mcp-server stdio
EOF

# Google Sheets wrapper
cat > ~/.mcp-wrappers/google-sheets-wrapper.sh << 'EOF'
#!/bin/bash
if [ -f ~/.env.mcp ]; then
    source ~/.env.mcp
fi
export GOOGLE_APPLICATION_CREDENTIALS="$GOOGLE_SHEETS_SERVICE_ACCOUNT_PATH"
exec /opt/homebrew/bin/uvx mcp-google-sheets
EOF

chmod +x ~/.mcp-wrappers/*.sh
echo "✓ Created MCP wrapper scripts"

# Create env template if it doesn't exist
if [ ! -f ~/.env.mcp ]; then
  cp "$DOTFILES/claude/.env.template" ~/.env.mcp
  chmod 600 ~/.env.mcp
  echo "✓ Created ~/.env.mcp from template (edit to add your API keys)"
fi

# --- Claude Code global instructions & slash commands ---
echo "→ Linking Claude Code global instructions..."
mkdir -p "$HOME/.claude"
backup_and_link "$DOTFILES/claude-code/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

echo "→ Linking Claude Code slash commands..."
mkdir -p "$HOME/.claude/commands"
for f in "$DOTFILES/claude-code/commands/"*.md; do
  [ -f "$f" ] && ln -sfn "$f" "$HOME/.claude/commands/$(basename "$f")"
done
echo "✓ Claude Code commands linked"

echo "→ Linking Claude desktop config..."
CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
mkdir -p "$CLAUDE_CONFIG_DIR"
backup_and_link "$DOTFILES/claude/claude_desktop_config.json" "$CLAUDE_CONFIG_DIR/claude_desktop_config.json"

echo "→ Linking Amp Code configuration..."
mkdir -p "$HOME/.config/amp"
backup_and_link "$DOTFILES/amp/settings.json" "$HOME/.config/amp/settings.json"

echo "→ Installing AI coding agents..."
npm install -g @openai/codex
npm install -g @sourcegraph/amp

echo "→ Configuring jenv (Java version management)..."
if have jenv; then
  # Initialize jenv first
  export PATH="$HOME/.jenv/bin:$PATH"
  export PROMPT_COMMAND="${PROMPT_COMMAND:-}"
  eval "$(jenv init -)"
  
  # Auto-discover and add installed JDKs to jenv
  echo "   Discovering installed Java versions..."
  for java_home in /Library/Java/JavaVirtualMachines/*/Contents/Home; do
    if [ -d "$java_home" ]; then
      version_info=$("$java_home/bin/java" -version 2>&1 | head -1)
      echo "   Found Java at: $java_home"
      echo "   Version: $version_info"
      jenv add "$java_home" 2>/dev/null || echo "   (already added to jenv)"
    fi
  done
  
  # Show available versions
  echo "   Available Java versions in jenv:"
  jenv versions
  
  echo "✓ jenv configured"
else
  echo "   jenv not found, install via Homebrew first"
fi

echo "✓ Install complete. Restart terminal or run: exec zsh"
