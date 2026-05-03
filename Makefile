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

.DEFAULT_GOAL := help

.PHONY: help install update backup-iterm restore-iterm iterm-profile brew-lock brew-update fonts doctor doctor-mcp helix zellij ghostty yazi git-config zed amp claude-code claude-code-settings claude-code-commands claude-code-mcp claude-code-mcp-wrappers mcp-gsuite-patch helix-lsp claude-tui claude-tui-install link-vault-skills site-serve site-preview site-build site-new test-obsidian cleanup cleanup-dry clean install-sdlc uninstall-sdlc doctor-sdlc

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^##@/ {printf "\n\033[1m%s\033[0m\n", substr($$0, 5)} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ Setup

install: backup-iterm ## Install everything (backs up iTerm2 prefs, runs install.sh, links profile)
	@echo "→ Running scripts/install.sh"
	@$(REPO_DIR)/scripts/install.sh
	@$(MAKE) iterm-profile
	@echo "✓ Install complete. If iTerm2 was open, quit & relaunch to load the new profile."

update: ## Update Homebrew packages & git submodules
	@echo "→ Updating Homebrew bundle"
	@brew bundle --file="$(BREWFILE)"
	@echo "→ Updating submodules"
	@$(REPO_DIR)/scripts/update-plugins.sh
	@echo "✓ Update complete."

##@ iTerm2

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

iterm-profile: ## Link iTerm2 Dynamic Profile JSON
	@mkdir -p "$(ITERM_DYNAMIC_DIR)"
	@ln -sfn "$(ITERM_PROFILE)" "$(ITERM_PROFILE_LINK)"
	@echo "✓ Linked iTerm2 profile → $(ITERM_PROFILE_LINK)"

##@ Homebrew

brew-lock: ## Re-dump current brew state to Brewfile
	@brew bundle dump --force --file="$(BREWFILE)"
	@echo "✓ Brewfile refreshed."

brew-update: ## brew update/upgrade/cleanup
	@brew update && brew upgrade && brew cleanup
	@echo "✓ Homebrew updated."

fonts: ## Ensure Nerd Font (if glyphs look off)
	@brew install --cask font-meslo-lg-nerd-font || true
	@echo "✓ Meslo Nerd Font ensured. Set it in iTerm2 > Profiles > Text."

##@ Health

doctor: ## Quick sanity checks
	@command -v zsh >/dev/null || (echo "zsh not found" && exit 1)
	@command -v brew >/dev/null || (echo "Homebrew not found" && exit 1)
	@command -v hx >/dev/null || (echo "helix not found - run: brew install helix" && exit 1)
	@command -v cmux >/dev/null || (echo "cmux not found - run: brew install --cask cmux" && exit 1)
	@command -v zellij >/dev/null || (echo "zellij not found - run: brew install zellij" && exit 1)
	@command -v lazygit >/dev/null || (echo "lazygit not found - run: brew install lazygit" && exit 1)
	@command -v yazi >/dev/null || (echo "yazi not found - run: brew install yazi" && exit 1)
	@command -v delta >/dev/null || (echo "delta not found - run: brew install git-delta" && exit 1)
	@command -v amp >/dev/null || (echo "amp not found - run: npm install -g @sourcegraph/amp" && exit 1)
	@command -v claude-tui >/dev/null || (echo "claude-tui not found - run: make claude-tui-install" && exit 1)
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
	@# Check Obsidian CLI (used directly via Agent Skill, no MCP server)
	@echo "┌─ obsidian-cli (Agent Skill) ────────────────────────────────────┐"
	@if command -v obsidian >/dev/null 2>&1; then \
	  echo "│ ✓ obsidian CLI found"; \
	else \
	  echo "│ ✗ obsidian CLI not found"; \
	  echo "│   Requires Obsidian v1.12+ with Catalyst license"; \
	  echo "│   Enable: Settings → General → Command line interface"; \
	fi
	@if [ -f "$(REPO_DIR)/.claude/skills/obsidian-cli/SKILL.md" ]; then \
	  echo "│ ✓ Claude Code skill installed"; \
	else \
	  echo "│ ✗ Claude Code skill missing at .claude/skills/obsidian-cli/SKILL.md"; \
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
	for wrapper in github google-sheets mcp-gsuite; do \
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

##@ Configuration

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

ghostty: ## Link Ghostty configuration (used by cmux)
	@echo "→ Linking Ghostty configuration"
	@mkdir -p "$(HOME)/.config"
	@if [ -d "$(HOME)/.config/ghostty" ] && [ ! -L "$(HOME)/.config/ghostty" ]; then \
	  echo "⚠ ~/.config/ghostty already exists as a directory (not a symlink) — skipping"; \
	else \
	  ln -sfn "$(REPO_DIR)/ghostty" "$(HOME)/.config/ghostty"; \
	  echo "✓ ~/.config/ghostty → $(REPO_DIR)/ghostty"; \
	fi

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

amp: ## Link Amp Code configuration (Sourcegraph AI coding agent)
	@echo "→ Linking Amp Code configuration"
	@mkdir -p "$(HOME)/.config/amp"
	@ln -sfn "$(REPO_DIR)/amp/settings.json" "$(HOME)/.config/amp/settings.json"
	@echo "✓ ~/.config/amp/settings.json → $(REPO_DIR)/amp/settings.json"
	@echo "  Note: Run 'amp' to authenticate via browser, or set AMP_API_KEY in ~/.env.mcp"

##@ Claude Code

claude-code: ## Link Claude Code global instructions (CLAUDE.md) and skills
	@echo "→ Linking Claude Code global instructions"
	@mkdir -p "$(HOME)/.claude"
	@ln -sfn "$(REPO_DIR)/claude-code/CLAUDE.md" "$(HOME)/.claude/CLAUDE.md"
	@echo "✓ ~/.claude/CLAUDE.md → $(REPO_DIR)/claude-code/CLAUDE.md"
	@echo "→ Linking Claude Code global skills"
	@mkdir -p "$(HOME)/.claude/skills/obsidian-cli"
	@ln -sfn "$(REPO_DIR)/.claude/skills/obsidian-cli/SKILL.md" "$(HOME)/.claude/skills/obsidian-cli/SKILL.md"
	@echo "✓ ~/.claude/skills/obsidian-cli/ → $(REPO_DIR)/.claude/skills/obsidian-cli/"

claude-code-settings: ## Symlink Claude Code settings.json
	@echo "→ Linking Claude Code settings"
	@mkdir -p "$(HOME)/.claude"
	@if [ -e "$(HOME)/.claude/settings.json" ] && [ ! -L "$(HOME)/.claude/settings.json" ]; then \
	  ts=$$(date +"%Y%m%d_%H%M%S"); \
	  echo "→ Backing up ~/.claude/settings.json → ~/.claude/settings.json.bak.$$ts"; \
	  mv "$(HOME)/.claude/settings.json" "$(HOME)/.claude/settings.json.bak.$$ts"; \
	fi
	@ln -sfn "$(REPO_DIR)/claude-code/settings.json" "$(HOME)/.claude/settings.json"
	@echo "✓ ~/.claude/settings.json → $(REPO_DIR)/claude-code/settings.json"

claude-code-commands: ## Link Claude Code slash commands
	@mkdir -p "$(HOME)/.claude/commands"
	@for f in $(REPO_DIR)/claude-code/commands/*.md; do \
	  ln -sfn "$$f" "$(HOME)/.claude/commands/$$(basename $$f)"; \
	done
	@echo "✓ Claude Code commands linked to ~/.claude/commands/"

link-vault-skills: ## Mirror <vault>/agents/<name>/commands/*.md into ~/.claude/commands/
	@$(REPO_DIR)/scripts/link-vault-skills.sh
	@echo "✓ Vault skills linked. Override vault path with HUDSON_VAULT=..."

claude-code-mcp: ## Sync Claude Code MCP servers from mcp-servers.json to ~/.claude.json
	@echo "→ Syncing Claude Code MCP servers"
	@command -v jq >/dev/null || (echo "Error: jq not found - run: brew install jq" && exit 1)
	@if [ ! -f "$(HOME)/.claude.json" ]; then \
	  echo "Error: ~/.claude.json not found. Run 'claude' first to initialize."; \
	  exit 1; \
	fi
	@jq -s '.[0] + {mcpServers: .[1].mcpServers}' "$(HOME)/.claude.json" "$(REPO_DIR)/claude-code/mcp-servers.json" > "$(HOME)/.claude.json.tmp" \
	  && mv "$(HOME)/.claude.json.tmp" "$(HOME)/.claude.json"
	@echo "✓ MCP servers synced to ~/.claude.json"
	@echo "  Servers: $$(jq -r '.mcpServers | keys | join(", ")' "$(REPO_DIR)/claude-code/mcp-servers.json")"

claude-code-mcp-wrappers: ## Link MCP wrapper scripts to ~/.mcp-wrappers/
	@echo "→ Linking MCP wrapper scripts"
	@mkdir -p "$(HOME)/.mcp-wrappers"
	@for f in $(REPO_DIR)/mcp-wrappers/*.sh; do \
	  ln -sfn "$$f" "$(HOME)/.mcp-wrappers/$$(basename $$f)"; \
	done
	@echo "✓ MCP wrappers linked to ~/.mcp-wrappers/"
	@ls -1 "$(HOME)/.mcp-wrappers/"

launchpad: ## Create ~/.launchpad directories (hooks managed via claude-code-settings)
	@echo "→ Creating ~/.launchpad directories..."
	@mkdir -p "$(HOME)/.launchpad/sessions/active"
	@mkdir -p "$(HOME)/.launchpad/tasks/backlog"
	@mkdir -p "$(HOME)/.launchpad/tasks/active"
	@mkdir -p "$(HOME)/.launchpad/tasks/done"
	@mkdir -p "$(HOME)/.launchpad/inbox"
	@echo "✓ ~/.launchpad/ directories created"
	@echo "  Hooks: managed via settings.json (run make claude-code-settings)"
	@echo "  Server: cd ~/code/launchpad && make dev"

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

##@ Claude TUI

claude-tui: ## Run Claude TUI (install globally first with make claude-tui-install)
	@command -v claude-tui >/dev/null || (echo "claude-tui not found - run: make claude-tui-install" && exit 1)
	@claude-tui

claude-tui-install: ## Install/upgrade claude-tui globally via uv tool
	@echo "→ Installing claude-tui via uv"
	@command -v uv >/dev/null || (echo "Error: uv not found - run: brew install uv" && exit 1)
	@uv tool install --force --from "$(REPO_DIR)/claude-tui" claude-tui
	@echo "✓ claude-tui installed globally. Run 'claude-tui' from anywhere."

##@ Language Servers

helix-lsp: ## Install Helix language servers
	@echo "→ Installing language servers for Helix"
	@brew install pyright ruff typescript-language-server prettier jdtls
	@echo "✓ Language servers installed"
	@echo "→ Run 'hx --health python typescript java' to verify"

##@ Hugo Site

site-serve: ## Serve Hugo site locally with drafts and live reload
	@cd "$(REPO_DIR)/site" && hugo server --buildDrafts --navigateToChanged --baseURL http://localhost:1313/

site-preview: ## Build and open Hugo site in browser (live reload + drafts)
	@cd "$(REPO_DIR)/site" && open http://localhost:1313/ && hugo server --buildDrafts --navigateToChanged --baseURL http://localhost:1313/

site-build: ## Build Hugo site for production
	@cd "$(REPO_DIR)/site" && hugo --gc --minify

site-new: ## Create a new writing post (usage: make site-new TITLE=my-post-title)
	@test -n "$(TITLE)" || (echo "Usage: make site-new TITLE=my-post-title" && exit 1)
	@cd "$(REPO_DIR)/site" && hugo new "writing/$(TITLE).md"
	@echo "✓ Created site/content/writing/$(TITLE).md"

##@ Testing

test-obsidian: ## Run Obsidian CLI integration tests (requires running Obsidian)
	@$(REPO_DIR)/tests/obsidian-cli/run-tests.sh

##@ Agentic SDLC (opt-in — personal machines only)

install-sdlc: ## Install SDLC slash-commands and skills (NOT run by make install)
	@SDLC_DIR="$(REPO_DIR)/claude-code/sdlc"; \
	CMD_DST="$(HOME)/.claude/commands/sdlc"; \
	SKL_DST="$(HOME)/.claude/skills"; \
	if [ ! -d "$$SDLC_DIR" ]; then \
	  echo "✗ $$SDLC_DIR not found"; exit 1; \
	fi; \
	mkdir -p "$$CMD_DST" "$$SKL_DST"; \
	for f in "$$SDLC_DIR/commands/"*.md; do \
	  [ -f "$$f" ] && ln -sfn "$$f" "$$CMD_DST/$$(basename $$f)"; \
	done; \
	echo "✓ SDLC commands → ~/.claude/commands/sdlc/"; \
	for d in "$$SDLC_DIR/skills/"*/; do \
	  name=$$(basename "$$d"); \
	  ln -sfn "$$d" "$$SKL_DST/$$name"; \
	  echo "  ✓ skill: $$name"; \
	done; \
	echo "✓ SDLC installed."; \
	echo "  Bootstrap: /sdlc:bootstrap, /sdlc:import"; \
	echo "  Changes:   /sdlc:new, /sdlc:ff, /sdlc:continue, /sdlc:apply, /sdlc:verify, /sdlc:archive, /sdlc:explore"

uninstall-sdlc: ## Remove SDLC slash-commands and skills
	@SDLC_DIR="$(REPO_DIR)/claude-code/sdlc"; \
	CMD_DST="$(HOME)/.claude/commands/sdlc"; \
	SKL_DST="$(HOME)/.claude/skills"; \
	if [ -d "$$CMD_DST" ]; then \
	  find "$$CMD_DST" -maxdepth 1 -type l -delete 2>/dev/null || true; \
	  rmdir "$$CMD_DST" 2>/dev/null || true; \
	  echo "✓ Removed ~/.claude/commands/sdlc/"; \
	fi; \
	if [ -d "$$SDLC_DIR/skills" ]; then \
	  for d in "$$SDLC_DIR/skills/"*/; do \
	    name=$$(basename "$$d"); \
	    link="$$SKL_DST/$$name"; \
	    if [ -L "$$link" ]; then \
	      rm "$$link"; \
	      echo "  ✓ removed skill: $$name"; \
	    fi; \
	  done; \
	fi; \
	echo "✓ SDLC uninstalled"

doctor-sdlc: ## Check SDLC install status
	@SDLC_DIR="$(REPO_DIR)/claude-code/sdlc"; \
	CMD_DST="$(HOME)/.claude/commands/sdlc"; \
	SKL_DST="$(HOME)/.claude/skills"; \
	echo "═══════════════════════════════════════════════════════════════════"; \
	echo "Agentic SDLC Install Check"; \
	echo "═══════════════════════════════════════════════════════════════════"; \
	if [ -d "$$CMD_DST" ]; then \
	  echo "✓ commands dir: $$CMD_DST"; \
	  for f in "$$SDLC_DIR/commands/"*.md; do \
	    name=$$(basename "$$f"); \
	    if [ -L "$$CMD_DST/$$name" ]; then echo "  ✓ $$name"; else echo "  ✗ $$name (missing symlink)"; fi; \
	  done; \
	else \
	  echo "✗ commands not installed (run: make install-sdlc)"; \
	fi; \
	echo ""; \
	for d in "$$SDLC_DIR/skills/"*/; do \
	  name=$$(basename "$$d"); \
	  if [ -L "$$SKL_DST/$$name" ]; then echo "  ✓ skill: $$name"; else echo "  ✗ skill: $$name (missing)"; fi; \
	done

##@ Cleanup

cleanup-dry: ## Show what cleanup would kill (safe preview)
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "Dev Environment Cleanup — DRY RUN"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "┌─ Orphaned wrangler dev servers ─────────────────────────────────┐"
	@WRANGLER_COUNT=$$(ps aux | grep "wrangler.*dev\|wrangler-dist/cli.js dev" | grep -v grep | wc -l | tr -d ' '); \
	WRANGLER_MB=$$(ps aux | grep "wrangler.*dev\|wrangler-dist/cli.js dev" | grep -v grep | awk '{sum+=$$6} END {printf "%.0f", sum/1024}'); \
	echo "│ $$WRANGLER_COUNT processes using $${WRANGLER_MB:-0} MB"
	@echo "└─────────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "┌─ Orphaned workerd runtimes ─────────────────────────────────────┐"
	@WORKERD_COUNT=$$(ps aux | grep "workerd serve" | grep -v grep | wc -l | tr -d ' '); \
	WORKERD_MB=$$(ps aux | grep "workerd serve" | grep -v grep | awk '{sum+=$$6} END {printf "%.0f", sum/1024}'); \
	echo "│ $$WORKERD_COUNT processes using $${WORKERD_MB:-0} MB"
	@echo "└─────────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "┌─ Orphaned esbuild service processes ───────────────────────────┐"
	@ESBUILD_COUNT=$$(ps aux | grep "esbuild.*--service" | grep -v grep | wc -l | tr -d ' '); \
	ESBUILD_MB=$$(ps aux | grep "esbuild.*--service" | grep -v grep | awk '{sum+=$$6} END {printf "%.0f", sum/1024}'); \
	echo "│ $$ESBUILD_COUNT processes using $${ESBUILD_MB:-0} MB"
	@echo "└─────────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "┌─ EXITED Zellij sessions ────────────────────────────────────────┐"
	@if command -v zellij >/dev/null 2>&1; then \
	  EXITED=$$(zellij list-sessions 2>/dev/null | grep "EXITED" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $$1}'); \
	  if [ -n "$$EXITED" ]; then \
	    echo "$$EXITED" | while read -r s; do echo "│ $$s"; done; \
	  else \
	    echo "│ (none)"; \
	  fi; \
	else \
	  echo "│ zellij not found"; \
	fi
	@echo "└─────────────────────────────────────────────────────────────────┘"
	@echo ""
	@TOTAL=$$(( $$(ps aux | grep "wrangler.*dev\|wrangler-dist/cli.js dev" | grep -v grep | awk '{sum+=$$6} END {print int(sum/1024)}') \
	         + $$(ps aux | grep "workerd serve" | grep -v grep | awk '{sum+=$$6} END {print int(sum/1024)}') \
	         + $$(ps aux | grep "esbuild.*--service" | grep -v grep | awk '{sum+=$$6} END {print int(sum/1024)}') )); \
	echo "Total reclaimable: ~$${TOTAL} MB"
	@echo ""
	@echo "Run 'make cleanup' to kill these processes."

cleanup: ## Kill orphaned dev servers, workerd, esbuild and clean EXITED Zellij sessions
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "Dev Environment Cleanup"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo ""
	@# Kill wrangler dev servers
	@WRANGLER_COUNT=$$(pkill -f "wrangler-dist/cli.js dev" 2>/dev/null; echo $$?); \
	if [ "$$WRANGLER_COUNT" = "0" ]; then \
	  echo "✓ Killed orphaned wrangler dev servers"; \
	else \
	  echo "· No wrangler dev servers running"; \
	fi
	@# Kill workerd runtimes
	@WORKERD_COUNT=$$(pkill -f "workerd serve" 2>/dev/null; echo $$?); \
	if [ "$$WORKERD_COUNT" = "0" ]; then \
	  echo "✓ Killed orphaned workerd runtimes"; \
	else \
	  echo "· No workerd runtimes running"; \
	fi
	@# Kill esbuild service processes
	@ESBUILD_COUNT=$$(pkill -f "esbuild.*--service" 2>/dev/null; echo $$?); \
	if [ "$$ESBUILD_COUNT" = "0" ]; then \
	  echo "✓ Killed orphaned esbuild service processes"; \
	else \
	  echo "· No esbuild service processes running"; \
	fi
	@# Kill orphaned pywrangler/uv processes
	@pkill -f "pywrangler dev" 2>/dev/null && echo "✓ Killed orphaned pywrangler processes" || echo "· No pywrangler processes running"
	@echo ""
	@# Clean EXITED Zellij sessions
	@if command -v zellij >/dev/null 2>&1; then \
	  EXITED=$$(zellij list-sessions 2>/dev/null | grep "EXITED" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $$1}'); \
	  if [ -n "$$EXITED" ]; then \
	    echo "$$EXITED" | while read -r session; do \
	      zellij delete-session "$$session" 2>/dev/null && echo "✓ Deleted Zellij session: $$session"; \
	    done; \
	  else \
	    echo "· No EXITED Zellij sessions"; \
	  fi; \
	fi
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "✓ Cleanup complete. Run 'make cleanup-dry' to verify."
	@echo "═══════════════════════════════════════════════════════════════════"

clean: ## Remove symlinked iTerm2 profile (non-destructive)
	@rm -f "$(ITERM_PROFILE_LINK)"
	@echo "✓ Removed iTerm2 profile link."
