## Context

Claude Code stores per-project conversation history at `~/.claude/projects/<encoded-path>/sessions-index.json` with full transcripts as `.jsonl` files. The built-in `claude -r` opens an interactive picker but requires quitting any active session first. The `--fork-session` flag creates a new session from an existing one without modifying the original.

Zellij supports floating panes (`--floating`), auto-close on exit (`--close-on-exit`), and in-place pane replacement (`--in-place`) which suspends the underlying pane and restores it when the replacement exits. Keybindings can trigger `Run` actions to launch commands in new panes.

Current layout (`claude-dev.kdl`) has Claude Code in the top-left pane.

## Goals / Non-Goals

**Goals:**
- Browse past Claude Code sessions for the current project from within Zellij without interrupting the active session
- Preview conversation content before deciding to resume
- Fork a selected session into the active Claude pane position, with the original session suspended and restored on exit

**Non-Goals:**
- Modifying existing Zellij layouts (the feature works via keybinding + script, layout-agnostic)
- Cross-project session browsing (scoped to current working directory)
- Editing or deleting past sessions
- Any changes to Claude Code itself

## Decisions

### 1. fzf as the session picker

**Choice**: Use fzf with preview for the session browser.

**Rationale**: Already in the Brewfile, universally understood, supports preview panes natively, and exits cleanly (important for `--close-on-exit` behavior). Alternatives like custom TUI apps would add complexity without benefit.

### 2. Floating pane with toggle-then-replace flow

**Choice**: Launch the browser as a floating pane. On selection, hide the floating pane with `zellij action toggle-floating-panes` (returning focus to the Claude pane), then run `zellij action new-pane --in-place` to replace the Claude pane with the forked session.

**Rationale**: `--in-place` replaces the currently focused pane. By hiding the floating pane first, focus returns to the last focused tiled pane (Claude). The script continues executing after the floating pane is hidden, so it can issue the `new-pane --in-place` command. When the forked session exits, `--in-place` restores the original Claude session automatically.

**Alternative considered**: Opening the forked session in a new pane or tab. Rejected because it fragments the workspace and doesn't leverage the suspend/restore behavior of `--in-place`.

### 3. Project path resolution via CLAUDE_PROJECT_DIR or pwd

**Choice**: The script resolves the session index by encoding the current working directory (replacing `/` with `-`, prepending `-`) to find `~/.claude/projects/<encoded>/sessions-index.json`.

**Rationale**: This matches Claude Code's own path encoding scheme. The working directory is available inside any Zellij pane. No environment variable plumbing needed — just the same convention Claude Code uses.

### 4. Python for JSON parsing and preview generation

**Choice**: Use python3 for reading sessions-index.json and generating fzf input/preview.

**Rationale**: The session data is JSON with nested structures. Python is already available on macOS and handles JSON natively. Shell-only parsing with jq would be more fragile for the preview extraction from .jsonl transcript files.

### 5. Keybinding in pane mode: Ctrl+Space s

**Choice**: Add `bind "s"` to the existing pane mode (`Ctrl+Space` leader) to launch the session browser.

**Rationale**: `s` for sessions is mnemonic. Pane mode is already the hub for workspace navigation (`h/l/j/k` for focus, `f` for float toggle, `z` for fullscreen). Adding session browsing here is consistent.

## Risks / Trade-offs

**[Risk] `toggle-floating-panes` hides ALL floating panes, not just the browser** → Acceptable trade-off. If the user has other floating panes open, they'll be hidden momentarily. The `new-pane --in-place` command executes immediately after, so the disruption is brief. Users can re-toggle floating panes afterward.

**[Risk] Focus may not return to the Claude pane after toggle** → Mitigation: Zellij returns focus to the last focused tiled pane. The natural workflow is: user is in Claude pane → triggers keybinding → floating opens → on selection, floating hides → focus returns to Claude. If focus is elsewhere, the wrong pane gets replaced. Document that the keybinding should be triggered while the Claude pane is focused.

**[Risk] Timing between toggle and new-pane commands** → Mitigation: Both are synchronous `zellij action` calls. The toggle completes before the next command runs. No sleep/delay needed.

**[Risk] sessions-index.json format changes in future Claude Code versions** → Mitigation: The script reads well-documented fields (sessionId, summary, firstPrompt, gitBranch, created, modified). Pin to known structure and fail gracefully if fields are missing.
