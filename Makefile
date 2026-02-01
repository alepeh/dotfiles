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

.PHONY: install backup-iterm update iterm-profile brew-lock brew-update fonts clean doctor doctor-mcp restore-iterm helix zellij yazi git-config zed claude-code claude-code-commands claude-code-mcp claude-code-mcp-wrappers mcp-gsuite-patch helix-lsp

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
	@[ -d "$(REPO_DIR)/yazi" ] || (echo "yazi config missing" && exit 1)
	@echo "✓ Doctor OK."

doctor-mcp: ## Check MCP server credentials and configuration
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "MCP Server Credentials Check"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo ""
	@# Check ~/.env.mcp exists
	@echo "┌─ Environment File ─────────────────────────────────────────────┐"
	@if [ -f "$(HOME)/.env.mcp" ]; then \
	  echo "│ ✓ ~/.env.mcp exists"; \
	else \
	  echo "│ ✗ ~/.env.mcp missing"; \
	  echo "│   Create it with: cp $(REPO_DIR)/claude/.env.template ~/.env.mcp"; \
	  echo "│   Then edit and add your credentials"; \
	fi
	@echo "└─────────────────────────────────────────────────────────────────┘"
	@echo ""
	@# Check Obsidian credentials
	@echo "┌─ mcp-obsidian ──────────────────────────────────────────────────┐"
	@if [ -f "$(HOME)/.env.mcp" ] && grep -q "OBSIDIAN_API_KEY=" "$(HOME)/.env.mcp" 2>/dev/null; then \
	  echo "│ ✓ OBSIDIAN_API_KEY is set"; \
	else \
	  echo "│ ✗ OBSIDIAN_API_KEY missing in ~/.env.mcp"; \
	  echo "│   Get it from: Obsidian → Settings → Community Plugins →"; \
	  echo "│                Local REST API → Copy API Key"; \
	fi
	@echo "└─────────────────────────────────────────────────────────────────┘"
	@echo ""
	@# Check GitHub credentials
	@echo "┌─ github-mcp-server ─────────────────────────────────────────────┐"
	@if [ -f "$(HOME)/.env.mcp" ] && grep -q "GITHUB_PERSONAL_ACCESS_TOKEN=" "$(HOME)/.env.mcp" 2>/dev/null && \
	   ! grep -q 'GITHUB_PERSONAL_ACCESS_TOKEN="your_' "$(HOME)/.env.mcp" 2>/dev/null; then \
	  echo "│ ✓ GITHUB_PERSONAL_ACCESS_TOKEN is set"; \
	else \
	  echo "│ ✗ GITHUB_PERSONAL_ACCESS_TOKEN missing or placeholder"; \
	  echo "│   Create at: https://github.com/settings/tokens"; \
	  echo "│   Required scopes: repo, read:org, read:user"; \
	fi
	@echo "└─────────────────────────────────────────────────────────────────┘"
	@echo ""
	@# Check Google Sheets credentials
	@echo "┌─ mcp-google-sheets ─────────────────────────────────────────────┐"
	@if [ -f "$(HOME)/.env.mcp" ]; then \
	  SA_PATH=$$(grep "GOOGLE_SHEETS_SERVICE_ACCOUNT_PATH=" "$(HOME)/.env.mcp" 2>/dev/null | cut -d'"' -f2 | sed "s|\$$HOME|$(HOME)|g"); \
	  if [ -n "$$SA_PATH" ] && [ -f "$$SA_PATH" ]; then \
	    echo "│ ✓ Service account JSON exists at $$SA_PATH"; \
	  else \
	    echo "│ ✗ Service account JSON missing"; \
	    echo "│   1. Go to: https://console.cloud.google.com/iam-admin/serviceaccounts"; \
	    echo "│   2. Create a service account"; \
	    echo "│   3. Create a JSON key and download it"; \
	    echo "│   4. Enable Google Sheets API: https://console.cloud.google.com/apis/library/sheets.googleapis.com"; \
	    echo "│   5. Set GOOGLE_SHEETS_SERVICE_ACCOUNT_PATH in ~/.env.mcp"; \
	  fi; \
	else \
	  echo "│ ✗ Cannot check - ~/.env.mcp missing"; \
	fi
	@echo "└─────────────────────────────────────────────────────────────────┘"
	@echo ""
	@# Check mcp-gsuite credentials
	@echo "┌─ mcp-gsuite (Gmail & Calendar) ─────────────────────────────────┐"
	@if [ -f "$(HOME)/.gauth.json" ]; then \
	  echo "│ ✓ ~/.gauth.json exists (OAuth credentials)"; \
	else \
	  echo "│ ✗ ~/.gauth.json missing"; \
	  echo "│   1. Go to: https://console.cloud.google.com/apis/credentials"; \
	  echo "│   2. Create OAuth 2.0 Client ID (Desktop app)"; \
	  echo "│   3. Download JSON and save as ~/.gauth.json"; \
	  echo "│   4. Enable Gmail API: https://console.cloud.google.com/apis/library/gmail.googleapis.com"; \
	  echo "│   5. Enable Calendar API: https://console.cloud.google.com/apis/library/calendar-json.googleapis.com"; \
	  echo "│"; \
	  echo "│   Required ~/.gauth.json format:"; \
	  echo '│   {"web":{"client_id":"...","client_secret":"...",'; \
	  echo '│    "redirect_uris":["http://localhost:4100/code"],'; \
	  echo '│    "auth_uri":"https://accounts.google.com/o/oauth2/auth",'; \
	  echo '│    "token_uri":"https://oauth2.googleapis.com/token"}}'; \
	fi
	@echo "│"
	@if [ -f "$(HOME)/.accounts.json" ]; then \
	  echo "│ ✓ ~/.accounts.json exists (account config)"; \
	else \
	  echo "│ ✗ ~/.accounts.json missing"; \
	  echo "│   Create ~/.accounts.json with your Google accounts:"; \
	  echo '│   {"accounts":[{"email":"you@gmail.com",'; \
	  echo '│    "account_type":"personal",'; \
	  echo '│    "extra_info":"Primary account"}]}'; \
	fi
	@echo "│"
	@if [ -d "$(HOME)/.local/share/mcp-gsuite-patched" ]; then \
	  echo "│ ✓ Patched mcp-gsuite installed"; \
	else \
	  echo "│ ✗ Patched mcp-gsuite missing"; \
	  echo "│   Run: make mcp-gsuite-patch"; \
	  echo "│   (Fixes JSON schema bug - see Issue #47)"; \
	fi
	@echo "└─────────────────────────────────────────────────────────────────┘"
	@echo ""
	@# Check MCP wrapper scripts
	@echo "┌─ MCP Wrapper Scripts ───────────────────────────────────────────┐"
	@MISSING=0; \
	for wrapper in obsidian github google-sheets mcp-gsuite; do \
	  if [ -f "$(HOME)/.mcp-wrappers/$${wrapper}-wrapper.sh" ]; then \
	    echo "│ ✓ $${wrapper}-wrapper.sh"; \
	  else \
	    echo "│ ✗ $${wrapper}-wrapper.sh missing"; \
	    MISSING=1; \
	  fi; \
	done; \
	if [ $$MISSING -eq 1 ]; then \
	  echo "│   Run: make claude-code-mcp-wrappers"; \
	fi
	@echo "└─────────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "Run 'make claude-code-mcp' to sync MCP config to ~/.claude.json"
	@echo "═══════════════════════════════════════════════════════════════════"

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

yazi: ## Link Yazi configuration (file manager)
	@echo "→ Linking Yazi configuration"
	@mkdir -p "$(HOME)/.config"
	@ln -sfn "$(REPO_DIR)/yazi" "$(HOME)/.config/yazi"
	@echo "✓ ~/.config/yazi → $(REPO_DIR)/yazi"

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

claude-code-commands: ## Link Claude Code slash commands
	@mkdir -p "$(HOME)/.claude/commands"
	@for f in $(REPO_DIR)/claude-code/commands/*.md; do \
	  ln -sfn "$$f" "$(HOME)/.claude/commands/$$(basename $$f)"; \
	done
	@echo "✓ Claude Code commands linked to ~/.claude/commands/"

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

claude-code-mcp-wrappers: ## Link MCP wrapper scripts to ~/.mcp-wrappers/
	@echo "→ Linking MCP wrapper scripts"
	@mkdir -p "$(HOME)/.mcp-wrappers"
	@for f in $(REPO_DIR)/mcp-wrappers/*.sh; do \
	  ln -sfn "$$f" "$(HOME)/.mcp-wrappers/$$(basename $$f)"; \
	done
	@echo "✓ MCP wrappers linked to ~/.mcp-wrappers/"
	@ls -1 "$(HOME)/.mcp-wrappers/"

mcp-gsuite-patch: ## Clone and patch mcp-gsuite to fix JSON schema bug (Issue #47)
	@echo "→ Creating patched mcp-gsuite (fixes JSON schema validation error)"
	@echo "  See: https://github.com/MarkusPfundstein/mcp-gsuite/issues/47"
	@rm -rf "$(HOME)/.local/share/mcp-gsuite-patched"
	@mkdir -p "$(HOME)/.local/share"
	@git clone --depth 1 https://github.com/MarkusPfundstein/mcp-gsuite.git \
	  "$(HOME)/.local/share/mcp-gsuite-patched" 2>/dev/null || \
	  (echo "Error: Failed to clone mcp-gsuite" && exit 1)
	@# Fix: Remove invalid "required": False from property definition
	@# This violates JSON Schema draft 2020-12 (required should be array at object level)
	@sed -i '' '/"required": False/d' \
	  "$(HOME)/.local/share/mcp-gsuite-patched/src/mcp_gsuite/tools_gmail.py"
	@echo "✓ Patched mcp-gsuite installed to ~/.local/share/mcp-gsuite-patched"
	@echo "  Note: Wrapper script already configured to use this location"

helix-lsp: ## Install Helix language servers
	@echo "→ Installing language servers for Helix"
	@brew install pyright ruff typescript-language-server prettier jdtls
	@echo "✓ Language servers installed"
	@echo "→ Run 'hx --health python typescript java' to verify"
