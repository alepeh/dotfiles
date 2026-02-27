## ADDED Requirements

### Requirement: A cmux notification hook script exists in the dotfiles repo
A shell script SHALL exist at `claude-code/hooks/cmux-notify.sh` that sends cmux notifications via the `cmux notify` CLI command.

#### Scenario: Hook script is present and executable
- **WHEN** the dotfiles repo is checked out
- **THEN** `claude-code/hooks/cmux-notify.sh` exists and has executable permissions

### Requirement: The hook fires a notification when Claude Code stops
The hook SHALL send a cmux notification with title "Claude Code" and body "Session complete" when it receives a `Stop` event.

#### Scenario: Claude Code session ends inside cmux
- **WHEN** Claude Code finishes and the `Stop` hook fires inside a cmux terminal
- **THEN** `cmux notify --title "Claude Code" --body "Session complete"` is executed and the cmux notification ring appears

#### Scenario: Claude Code session ends outside cmux
- **WHEN** Claude Code finishes and the `Stop` hook fires outside cmux (socket not present)
- **THEN** the hook exits silently with status 0 and no notification is sent

### Requirement: The hook fires a notification when a subagent task completes
The hook SHALL send a cmux notification with title "Claude Code" and body "Agent finished" when it receives a `PostToolUse` event for the `Task` tool.

#### Scenario: Subagent completes inside cmux
- **WHEN** a Claude Code subagent (Task tool) completes inside a cmux terminal
- **THEN** `cmux notify --title "Claude Code" --body "Agent finished"` is executed

### Requirement: The hook is a no-op outside cmux
The hook SHALL check for the cmux socket at `/tmp/cmux.sock` and exit immediately if the socket does not exist. This ensures the hook is safe to register globally.

#### Scenario: Socket not present
- **WHEN** the hook runs and `/tmp/cmux.sock` does not exist
- **THEN** the script exits with status 0 without executing any cmux commands

### Requirement: Claude Code settings.json registers the hook
The dotfiles SHALL configure `~/.claude/settings.json` to register `cmux-notify.sh` for the `Stop` event and `PostToolUse` event (matching the `Task` tool).

#### Scenario: Hook is registered on install
- **WHEN** the Claude Code dotfiles are linked via `make claude-code`
- **THEN** `~/.claude/settings.json` includes the hook entries for `Stop` and `PostToolUse` events
