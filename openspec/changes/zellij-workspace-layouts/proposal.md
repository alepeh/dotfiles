## Why

Claude Code stores full conversation history per project (sessions-index.json + .jsonl transcripts), but there's no way to browse or revisit past sessions without quitting the current one and running `claude -r`. In a Zellij-based terminal IDE, this means losing context to check what you worked on before. A lightweight session browser — triggered via keybinding, displayed as a floating pane, with the ability to fork and resume past conversations — brings Cursor-like conversation history into the terminal workflow.

## What Changes

- Add a `claude-sessions` shell script that reads Claude Code's session index for the current project, presents an fzf picker with conversation preview, and on selection replaces the active Claude pane in-place with a forked session
- Add a Zellij keybinding (`Ctrl+Space s`) that launches the session browser as a floating pane with close-on-exit behavior
- No changes to existing layouts — the keybinding and script work with any layout that has a Claude pane

## Capabilities

### New Capabilities
- `claude-session-browser`: A floating fzf-based session picker that reads Claude Code's per-project conversation history, previews past conversations, and forks selected sessions into the active Claude pane using Zellij's in-place pane replacement

### Modified Capabilities

## Impact

- **scripts/**: New `claude-sessions` script
- **zellij/config.kdl**: New keybinding in pane mode
- **Makefile**: Symlink target for the new script (into PATH)
- **Dependencies**: Requires `fzf` (already in Brewfile), `python3` or `jq` for JSON parsing
