## ADDED Requirements

### Requirement: claude-tui can launch a dev environment in cmux
The `claude-tui` application SHALL include a `_launch_cmux_dev()` function that sets up the standard dev layout using the cmux CLI: Claude Code in the first workspace with Helix as a right split, lazygit in a second workspace, and Yazi with Helix in a third workspace.

#### Scenario: Launching a new session in cmux
- **WHEN** a user starts a new session from claude-tui and cmux is the active backend
- **THEN** cmux creates workspaces with Claude Code + Helix (dev), lazygit (git), and Yazi + Helix (files)

#### Scenario: Resuming a session in cmux
- **WHEN** a user resumes an existing session from claude-tui and cmux is the active backend
- **THEN** cmux creates the dev layout with Claude Code launched using `--resume <session-id>`

### Requirement: claude-tui auto-detects cmux as the active backend
The `claude-tui` application SHALL detect whether cmux is running by checking for the cmux socket at `/tmp/cmux.sock`. If cmux is detected, sessions launch via cmux; otherwise, the existing Zellij+iTerm2 path is used.

#### Scenario: cmux is running
- **WHEN** a user triggers a session launch and `/tmp/cmux.sock` exists
- **THEN** claude-tui uses the cmux backend to create workspaces and panes

#### Scenario: cmux is not running
- **WHEN** a user triggers a session launch and `/tmp/cmux.sock` does not exist
- **THEN** claude-tui falls back to the existing `_launch_zellij_dev()` function with iTerm2

### Requirement: The cmux launch function uses the cmux CLI for workspace and pane setup
The cmux backend SHALL use `cmux` CLI commands to create workspaces, split panes, and run commands. It SHALL NOT generate Zellij KDL layouts or rely on Zellij for multiplexing.

#### Scenario: Workspace creation via CLI
- **WHEN** `_launch_cmux_dev()` runs
- **THEN** it invokes cmux CLI commands to create named workspaces and split panes with the appropriate commands (claude, hx, lazygit, yazi)

### Requirement: The Zellij launch path remains functional
The existing `_launch_zellij_dev()` function and its iTerm2/Terminal.app integration SHALL remain unchanged and continue to work as before.

#### Scenario: Zellij fallback works
- **WHEN** cmux is not detected and a user launches a session
- **THEN** the session launches in a Zellij session inside iTerm2, identical to the current behavior
