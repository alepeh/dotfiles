## ADDED Requirements

### Requirement: Session browser script discovers sessions for current project
The `claude-sessions` script SHALL resolve the current working directory to the corresponding Claude Code sessions-index.json path and read all session entries for the project.

#### Scenario: Sessions exist for current project
- **WHEN** the script runs in a directory that has Claude Code session history
- **THEN** it reads `~/.claude/projects/<encoded-path>/sessions-index.json` and lists all sessions sorted by modification date (most recent first)

#### Scenario: No sessions exist for current project
- **WHEN** the script runs in a directory with no Claude Code session history
- **THEN** it displays a message "No sessions found for this project" and exits cleanly

#### Scenario: Sessions index file is missing or corrupt
- **WHEN** the sessions-index.json file does not exist or contains invalid JSON
- **THEN** the script displays an error message and exits with a non-zero status

### Requirement: Session browser presents an fzf picker with conversation preview
The script SHALL display sessions in an fzf interface showing date, summary, message count, and git branch, with a preview pane that shows the conversation messages.

#### Scenario: Browsing sessions
- **WHEN** the fzf picker is displayed
- **THEN** each entry shows the format: `<date>  <message-count> msgs  <branch>  <summary>`

#### Scenario: Previewing a session
- **WHEN** the user navigates to a session entry in fzf
- **THEN** the preview pane displays the user and assistant text messages from the session transcript, excluding tool calls and system messages

#### Scenario: User cancels selection
- **WHEN** the user presses Escape in the fzf picker
- **THEN** the script exits without any side effects (no pane changes)

### Requirement: Selecting a session forks it into the active Claude pane
The script SHALL, upon session selection, hide floating panes to restore focus to the Claude pane, then replace it in-place with a forked Claude Code session.

#### Scenario: Successful fork
- **WHEN** the user selects a session and presses Enter
- **THEN** the script runs `zellij action toggle-floating-panes` followed by `zellij action new-pane --in-place -- claude -r <session-id> --fork-session`

#### Scenario: Forked session exits
- **WHEN** the user exits the forked Claude Code session
- **THEN** Zellij restores the original Claude pane that was suspended by `--in-place`

### Requirement: Zellij keybinding launches session browser
The Zellij configuration SHALL include a keybinding in pane mode that launches the session browser as a floating pane with close-on-exit behavior.

#### Scenario: Triggering the session browser
- **WHEN** the user presses `Ctrl+Space` then `s`
- **THEN** Zellij opens a floating pane running the `claude-sessions` script with `--close-on-exit` behavior

### Requirement: Session browser script is installed via dotfiles
The `claude-sessions` script SHALL be placed in `scripts/claude-sessions` and symlinked to a location on PATH during `make install`.

#### Scenario: Fresh install includes the script
- **WHEN** a user runs `make install`
- **THEN** the `claude-sessions` script is available on PATH

#### Scenario: Script is executable
- **WHEN** the `claude-sessions` script is installed
- **THEN** it has executable permissions
