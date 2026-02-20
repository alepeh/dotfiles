## 1. Session Browser Script

- [x] 1.1 Create `scripts/claude-sessions` script with project path resolution (pwd → encoded path → sessions-index.json)
- [x] 1.2 Add session listing: read sessions-index.json, sort by modified date, format as fzf input (`date  msgs  branch  summary`)
- [x] 1.3 Add conversation preview: parse .jsonl transcript to extract user/assistant text messages for fzf preview
- [x] 1.4 Add fork action: on fzf selection, run `zellij action toggle-floating-panes` then `zellij action new-pane --in-place -- claude -r <session-id> --fork-session`
- [x] 1.5 Add error handling: no sessions found, missing index file, user cancels (Esc)

## 2. Zellij Integration

- [x] 2.1 Add keybinding `bind "s"` in pane mode in `zellij/config.kdl` to launch `claude-sessions` as a floating pane with close-on-exit
- [x] 2.2 Verify the toggle-floating → new-pane-in-place sequence works correctly (focus returns to Claude pane, in-place replaces it, original restores on exit)

## 3. Install Integration

- [x] 3.1 Make `scripts/claude-sessions` executable and add symlink to PATH in `scripts/install.sh` or Makefile
