# Makefile for macOS-only dotfiles (Oh My Zsh + P10k + Brew)
SHELL := /bin/bash
REPO_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BREWFILE := $(REPO_DIR)/Brewfile

# iTerm2 bits
ITERM_PROFILE := $(REPO_DIR)/iterm2/Dotfiles-MinimalP10k.json
ITERM_DYNAMIC_DIR := $(HOME)/Library/Application\ Support/iTerm2/DynamicProfiles
ITERM_PROFILE_LINK := $(ITERM_DYNAMIC_DIR)/Dotfiles-MinimalP10k.json

ITERM_PREFS := $(HOME)/Library/Preferences/com.googlecode.iterm2.plist
BACKUP_DIR := $(REPO_DIR)/backups/iterm2

.PHONY: install backup-iterm update iterm-profile brew-lock brew-update fonts clean doctor restore-iterm helix zellij git-config zed claude-code claude-code-mcp

install: backup-iterm ## Install everything (backs up iTerm2 prefs, runs install.sh, links profile)
	@echo "→ Running scripts/install.sh"
	@$(REPO_DIR)/scripts/install.sh
	@$(MAKE) iterm-profile
	@echo "✓ Install complete. If iTerm2 was open, quit & relaunch to load the new profile."

backup-iterm: ## Backup iTerm2 preferences plist to repo backups folder
	@mkdir -p "$(BACKUP_DIR)"
	@ts=$$(date +"%Y%m%d_%H%M%S"); \
	if [ -f "$(ITERM_PREFS)" ]; then \
	  cp "$(ITERM_PREFS)" "$(BACKUP_DIR)/com.googlecode.iterm2.$${ts}.plist"; \
	  echo "✓ Backed up iTerm2 prefs → $(BACKUP_DIR)/com.googlecode.iterm2.$${ts}.plist"; \
	else \
	  echo "iTerm2 prefs not found at: $(ITERM_PREFS) (skipping)"; \
	fi

restore-iterm: ## Restore the most recent iTerm2 prefs backup
	@latest=$$(ls -1t "$(BACKUP_DIR)"/com.googlecode.iterm2.*.plist 2>/dev/null | head -n1); \
	if [ -n "$$latest" ]; then \
	  echo "→ Restoring $$latest → $(ITERM_PREFS)"; \
	  cp "$$latest" "$(ITERM_PREFS)"; \
	  echo "✓ Restored. Quit & relaunch iTerm2 for changes to take effect."; \
	else \
	  echo "No backups found in $(BACKUP_DIR)"; \
	fi

update: ## Update Homebrew packages & git submodules
	@echo "→ Updating Homebrew bundle"
	@brew bundle --file="$(BREWFILE)"
	@echo "→ Updating submodules"
	@$(REPO_DIR)/scripts/update-plugins.sh
	@echo "✓ Update complete."

iterm-profile: ## Link iTerm2 Dynamic Profile JSON
	@mkdir -p "$(ITERM_DYNAMIC_DIR)"
	@ln -sfn "$(ITERM_PROFILE)" "$(ITERM_PROFILE_LINK)"
	@echo "✓ Linked iTerm2 profile → $(ITERM_PROFILE_LINK)"

brew-lock: ## Re-dump current brew state to Brewfile
	@brew bundle dump --force --file="$(BREWFILE)"
	@echo "✓ Brewfile refreshed."

brew-update: ## brew update/upgrade/cleanup
	@brew update && brew upgrade && brew cleanup
	@echo "✓ Homebrew updated."

fonts: ## Ensure Nerd Font (if glyphs look off)
	@brew install --cask font-meslo-lg-nerd-font || true
	@echo "✓ Meslo Nerd Font ensured. Set it in iTerm2 > Profiles > Text."

doctor: ## Quick sanity checks
	@command -v zsh >/dev/null || (echo "zsh not found" && exit 1)
	@command -v brew >/dev/null || (echo "Homebrew not found" && exit 1)
	@command -v hx >/dev/null || (echo "helix not found - run: brew install helix" && exit 1)
	@command -v zellij >/dev/null || (echo "zellij not found - run: brew install zellij" && exit 1)
	@command -v lazygit >/dev/null || (echo "lazygit not found - run: brew install lazygit" && exit 1)
	@command -v yazi >/dev/null || (echo "yazi not found - run: brew install yazi" && exit 1)
	@command -v delta >/dev/null || (echo "delta not found - run: brew install git-delta" && exit 1)
	@[ -d "$(REPO_DIR)/omz/ohmyzsh" ] || (echo "oh-my-zsh submodule missing" && exit 1)
	@[ -f "$(REPO_DIR)/zsh/.zshrc" ] || (echo ".zshrc missing" && exit 1)
	@[ -d "$(REPO_DIR)/helix" ] || (echo "helix config missing" && exit 1)
	@[ -d "$(REPO_DIR)/zellij" ] || (echo "zellij config missing" && exit 1)
	@echo "✓ Doctor OK."

clean: ## Remove symlinked iTerm2 profile (non-destructive)
	@rm -f "$(ITERM_PROFILE_LINK)"
	@echo "✓ Removed iTerm2 profile link."

helix: ## Link Helix editor configuration
	@echo "→ Linking Helix configuration"
	@mkdir -p "$(HOME)/.config"
	@ln -sfn "$(REPO_DIR)/helix" "$(HOME)/.config/helix"
	@echo "✓ ~/.config/helix → $(REPO_DIR)/helix"

zellij: ## Link Zellij configuration
	@echo "→ Linking Zellij configuration"
	@mkdir -p "$(HOME)/.config"
	@ln -sfn "$(REPO_DIR)/zellij" "$(HOME)/.config/zellij"
	@echo "✓ ~/.config/zellij → $(REPO_DIR)/zellij"

git-config: ## Link Git configuration (delta, aliases)
	@echo "→ Linking Git configuration"
	@ln -sfn "$(REPO_DIR)/git/config" "$(HOME)/.gitconfig"
	@echo "✓ ~/.gitconfig → $(REPO_DIR)/git/config"
	@echo "   Note: Add machine-specific settings to ~/.gitconfig.local"

zed: ## Link Zed editor configuration
	@echo "→ Linking Zed configuration"
	@mkdir -p "$(HOME)/.config/zed"
	@ln -sfn "$(REPO_DIR)/zed/settings.json" "$(HOME)/.config/zed/settings.json"
	@echo "✓ ~/.config/zed/settings.json → $(REPO_DIR)/zed/settings.json"

claude-code: ## Link Claude Code global instructions (CLAUDE.md)
	@echo "→ Linking Claude Code global instructions"
	@mkdir -p "$(HOME)/.claude"
	@ln -sfn "$(REPO_DIR)/claude-code/CLAUDE.md" "$(HOME)/.claude/CLAUDE.md"
	@echo "✓ ~/.claude/CLAUDE.md → $(REPO_DIR)/claude-code/CLAUDE.md"
	@echo "  Note: This provides git workflow best practices for Claude Code"

claude-code-mcp: ## Sync Claude Code MCP servers from settings.json to ~/.claude.json
	@echo "→ Syncing Claude Code MCP servers"
	@command -v jq >/dev/null || (echo "Error: jq not found - run: brew install jq" && exit 1)
	@if [ ! -f "$(HOME)/.claude.json" ]; then \
	  echo "Error: ~/.claude.json not found. Run 'claude' first to initialize."; \
	  exit 1; \
	fi
	@jq -s '.[0] * {mcpServers: .[1].mcpServers}' "$(HOME)/.claude.json" "$(REPO_DIR)/claude-code/settings.json" > "$(HOME)/.claude.json.tmp" \
	  && mv "$(HOME)/.claude.json.tmp" "$(HOME)/.claude.json"
	@echo "✓ MCP servers synced to ~/.claude.json"
	@echo "  Servers: $$(jq -r '.mcpServers | keys | join(", ")' "$(REPO_DIR)/claude-code/settings.json")"
