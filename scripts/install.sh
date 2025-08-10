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

# --- Neovim + LazyVim (repo-managed) ---
NVIM_HOME="$HOME/.config/nvim"
NVIM_REPO="$DOTFILES/nvim"

# If ~/.config/nvim exists and is not a symlink, back it up (and optionally migrate into repo)
if [ -e "$NVIM_HOME" ] && [ ! -L "$NVIM_HOME" ]; then
  backup="$NVIM_HOME.bak.$(timestamp)"
  echo "→ Backing up existing Neovim config → $backup"
  mv "$NVIM_HOME" "$backup"
  # If the repo doesn't already have a config, migrate the user's backed-up config into the repo
  if [ ! -d "$NVIM_REPO" ]; then
    echo "→ Migrating previous Neovim config into repo"
    mv "$backup" "$NVIM_REPO"
  fi
fi

# If repo has no nvim config yet, install LazyVim starter into the repo
if [ ! -d "$NVIM_REPO" ]; then
  echo "→ Installing LazyVim into repo ($NVIM_REPO)..."
  git clone https://github.com/LazyVim/starter "$NVIM_REPO"
  rm -rf "$NVIM_REPO/.git"   # keep it as your config, not a git sub-repo
else
  echo "✓ Repo Neovim config present at $NVIM_REPO"
fi

# Symlink ~/.config/nvim -> $DOTFILES/nvim
mkdir -p "$(dirname "$NVIM_HOME")"
ln -sfn "$NVIM_REPO" "$NVIM_HOME"
echo "✓ Linked $NVIM_HOME → $NVIM_REPO"

echo "→ Installing fzf keybindings/completions..."
"$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc

echo "→ Linking dotfiles (with backups if needed)..."
backup_and_link "$DOTFILES/zsh/.zshenv"    "$HOME/.zshenv"
backup_and_link "$DOTFILES/zsh/.zshrc"     "$HOME/.zshrc"
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

echo "→ Installing  Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

echo "→ Install Codex CLI..."
npm install -g @openai/codex

echo "✓ Install complete. Restart terminal or run: exec zsh"
