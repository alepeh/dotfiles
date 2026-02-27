## Context

The current terminal IDE stack is: iTerm2 (terminal emulator) → Zellij (multiplexer) → Claude Code / Helix / lazygit / yazi. Session management is handled by `claude-tui`, which generates Zellij KDL layouts and launches them inside iTerm2 tabs.

cmux (v0.61.0) is a native macOS terminal built on Ghostty's rendering engine (libghostty). It provides built-in workspaces (vertical tabs), split panes, notification rings, an embedded browser, and a CLI/socket API — purpose-built for AI agent workflows. It reads Ghostty config from `~/.config/ghostty/config` for fonts, colors, and themes.

cmux is already installed via Homebrew cask. The Brewfile and doctor check have been added.

## Goals / Non-Goals

**Goals:**
- Provide a cmux-based dev environment as an alternative to the Zellij+iTerm2 stack
- Create a Ghostty config for terminal appearance (fonts, theme, colors)
- Fire cmux notification rings when Claude Code finishes or needs attention
- Enable `claude-tui` to launch sessions in cmux alongside the existing Zellij path

**Non-Goals:**
- Removing Zellij or iTerm2 configs — both remain as fallback
- Replicating every Zellij layout variant (cursor-dev, review, minimal) — start with the primary `claude-dev` equivalent only
- Socket API automation beyond notifications — defer advanced scripting
- Session restore for live Claude Code processes (cmux limitation: live process state is not yet restored on relaunch)

## Decisions

### 1. Ghostty config managed in dotfiles repo

Create `ghostty/config` in the dotfiles repo, symlinked to `~/.config/ghostty/config` via `make install`. This follows the existing pattern (helix → `~/.config/helix`, zellij → `~/.config/zellij`).

Config will include: font (MesloLGS Nerd Font, already in Brewfile), font size, theme (catppuccin-mocha to match Zellij), and window padding.

**Alternative considered:** Rely on cmux defaults. Rejected because the font and theme need to match the existing stack, and Ghostty config is also useful independently of cmux.

### 2. cmux workspaces replace Zellij tabs — no Zellij inside cmux

cmux has native workspaces (⌘1-8) and split panes (⌘D / ⌘⇧D). Running Zellij inside cmux would double-up on multiplexing with conflicting keybindings. The `claude-dev` layout translates to:

- **Workspace 1 "dev"**: Claude Code (left split) + Helix (right split), shell below
- **Workspace 2 "git"**: lazygit
- **Workspace 3 "files"**: Yazi (left split) + Helix (right split)

These are set up programmatically via the `cmux` CLI when launching a session, rather than a declarative layout file (cmux has no KDL-equivalent config format).

**Alternative considered:** Running Zellij inside cmux. Rejected — it defeats the purpose and creates keybinding conflicts. cmux's native workspace/split model is sufficient.

### 3. Notification hook as a shell script in dotfiles

Create `claude-code/hooks/cmux-notify.sh` in the dotfiles repo. The hook uses the `cmux notify` CLI command and is configured in `~/.claude/settings.json` under the `hooks` key. It fires on:

- `Stop` event — "Session complete" notification when Claude finishes
- `PostToolUse` for `Task` tool — "Agent finished" when a subagent completes

The hook guards on `[ -S /tmp/cmux.sock ]` so it's a no-op outside cmux. This means the hook can be registered globally without breaking non-cmux sessions.

**Alternative considered:** OSC 777 escape sequences. Rejected — the CLI approach is clearer, supports title/subtitle/body, and matches the documented Claude Code hook pattern.

### 4. claude-tui gets a cmux backend alongside Zellij

Add a `_launch_cmux_dev()` function to `claude-tui/claude_tui/app.py` that uses the `cmux` CLI to:
1. Create a new workspace
2. Run Claude Code (with `--resume` if resuming a session)
3. Split and run Helix, lazygit, yazi in additional workspaces

The launch function is selected based on detecting whether `cmux` is running (check for `/tmp/cmux.sock` or `pgrep cmux`). If cmux is running, use it; otherwise fall back to the existing Zellij+iTerm2 path.

**Alternative considered:** User config toggle in `claude-tui`. Rejected for now — auto-detection is simpler and the right default. Can add a config override later if needed.

### 5. Makefile targets for Ghostty config

Add a `ghostty` target to the Makefile that symlinks `ghostty/` → `~/.config/ghostty/`. Add it to the main `install` target. Follow the existing pattern of helix/zellij targets.

## Risks / Trade-offs

- **cmux is young software (v0.61)** → Keep Zellij as fallback. Don't remove any existing config.
- **No declarative layout files** → Workspace setup via CLI is imperative and may be fragile across cmux versions. Mitigation: keep the launch script simple, test against current version.
- **No live process restore** → If cmux restarts, Claude Code sessions are lost. Mitigation: `claude-tui` can re-launch with `--resume` to pick up where the session left off.
- **Hook socket guard** → If cmux changes its socket path from `/tmp/cmux.sock`, the hook will silently no-op. Mitigation: use `command -v cmux` as a secondary check if needed.
- **Keybinding muscle memory** → Users accustomed to `Ctrl+Space` leader will need to learn `⌘`-based shortcuts. Mitigation: document the mapping in a help reference.
