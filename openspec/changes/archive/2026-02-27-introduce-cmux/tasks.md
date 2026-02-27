## 1. Installation (cmux-install)

- [x] 1.1 Add `cask "cmux"` to Brewfile
- [x] 1.2 Add `command -v cmux` check to `make doctor` target in Makefile

## 2. Ghostty Config (cmux-config)

- [x] 2.1 Create `ghostty/config` with font (MesloLGS Nerd Font), theme (catppuccin-mocha), font size, and window padding
- [x] 2.2 Add `ghostty` Makefile target that symlinks `ghostty/` → `~/.config/ghostty/` (warn if directory already exists)
- [x] 2.3 Add `ghostty` to the `install` target dependencies in Makefile

## 3. Notification Hook (cmux-notifications)

- [x] 3.1 Create `claude-code/hooks/cmux-notify.sh` with socket guard, Stop handler, and PostToolUse/Task handler
- [x] 3.2 Make the hook script executable (`chmod +x`)
- [x] 3.3 Register the hook in `~/.claude/settings.json` under `hooks` for Stop and PostToolUse events
- [x] 3.4 Verify hook is a no-op outside cmux (test without socket present)

## 4. Session Launch (cmux-session-launch)

- [x] 4.1 Research cmux CLI commands for workspace creation, pane splitting, and running commands
- [x] 4.2 Add `_is_cmux_running()` detection function to `claude-tui/claude_tui/app.py` (check `/tmp/cmux.sock`)
- [x] 4.3 Implement `_launch_cmux_dev()` function that sets up dev/git/files workspaces via cmux CLI
- [x] 4.4 Wire auto-detection into `action_resume_session`, `_start_new_session`, and `_start_manual_session` to choose cmux or Zellij backend
- [x] 4.5 Verify existing `_launch_zellij_dev()` path still works unchanged
