# mcp-cleanup Specification

## Purpose
TBD - created by archiving change obsidian-cli-mcp. Update Purpose after archive.
## Requirements
### Requirement: Remove MCP server directory
The system SHALL delete the entire `mcp-servers/obsidian-cli-mcp/` directory including source code, tests, venv, lock file, and Makefile.

#### Scenario: No MCP server artifacts remain
- **WHEN** the change is applied
- **THEN** `mcp-servers/obsidian-cli-mcp/` does not exist

### Requirement: Remove wrapper script
The system SHALL delete `mcp-wrappers/obsidian-wrapper.sh`.

#### Scenario: Wrapper script removed
- **WHEN** the change is applied
- **THEN** `mcp-wrappers/obsidian-wrapper.sh` does not exist
- **AND** `~/.mcp-wrappers/obsidian-wrapper.sh` symlink is noted for manual cleanup

### Requirement: Remove MCP settings entry
The system SHALL remove the `mcp-obsidian` entry from `claude-code/settings.json`.

#### Scenario: Settings file updated
- **WHEN** the change is applied
- **THEN** `claude-code/settings.json` contains no `mcp-obsidian` key
- **AND** all other MCP server entries remain unchanged

### Requirement: Update Makefile targets
The system SHALL remove the `obsidian-mcp` Make target and update `doctor-mcp` to check for the `obsidian` CLI binary instead of the MCP server venv. The `.PHONY` declaration SHALL be updated accordingly.

#### Scenario: obsidian-mcp target removed
- **WHEN** running `make help`
- **THEN** `obsidian-mcp` does not appear in the target list

#### Scenario: doctor-mcp checks CLI availability
- **WHEN** running `make doctor-mcp`
- **THEN** it checks for the `obsidian` CLI binary (not the MCP server venv)
- **AND** reports whether the CLI is available

### Requirement: Update doctor-mcp wrapper references
The `doctor-mcp` target SHALL remove references to `obsidian-wrapper.sh` from the MCP Wrapper Scripts check section.

#### Scenario: Wrapper check excludes obsidian
- **WHEN** running `make doctor-mcp`
- **THEN** the wrapper scripts check does not list `obsidian-wrapper.sh`

