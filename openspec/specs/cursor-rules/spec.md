# cursor-rules Specification

## Purpose
TBD - created by archiving change obsidian-cli-mcp. Update Purpose after archive.
## Requirements
### Requirement: Cursor rules file at standard location
The system SHALL provide a Cursor rules file at `.cursor/rules/obsidian-cli.mdc` with YAML frontmatter containing a `description` field for auto-triggering.

#### Scenario: Cursor loads the rule when relevant
- **WHEN** the user asks Cursor to interact with their Obsidian vault
- **THEN** Cursor loads the obsidian-cli rule based on the description match

### Requirement: Content parity with Claude Code skill
The Cursor rules file SHALL contain the same CLI instructions as the Claude Code skill: syntax reference, vault targeting (`vault=brain`), common patterns, silent failure workarounds, heading-edit recipe, and the `obsidian help` discovery directive.

#### Scenario: Same operation works in both tools
- **WHEN** a user asks "append to my daily note" in Cursor
- **THEN** Cursor runs the same `obsidian vault=brain daily:append content="..."` command that Claude Code would

### Requirement: Cursor-specific format
The rules file SHALL use the `.mdc` format (Markdown with YAML frontmatter) as expected by Cursor's `.cursor/rules/` directory convention.

#### Scenario: Valid Cursor rules file
- **WHEN** Cursor scans `.cursor/rules/`
- **THEN** it parses `obsidian-cli.mdc` without errors and registers it as an available rule

