## ADDED Requirements

### Requirement: Skill file at standard location
The system SHALL provide an Agent Skill file at `.claude/skills/obsidian-cli/SKILL.md` that follows the Agent Skills specification with YAML frontmatter containing `name` and `description` fields.

#### Scenario: Claude Code discovers the skill at startup
- **WHEN** Claude Code starts in the dotfiles repo
- **THEN** the skill appears in the available skills list with name `obsidian-cli`

#### Scenario: Skill activates on Obsidian-related requests
- **WHEN** the user asks to interact with their Obsidian vault
- **THEN** the agent loads the full SKILL.md body into context

### Requirement: Vault targeting defaults to brain
The skill SHALL instruct agents to use `vault=brain` as the first parameter on all CLI commands, matching the user's vault name.

#### Scenario: Agent reads a note
- **WHEN** the agent needs to read a vault file
- **THEN** it runs `obsidian vault=brain read path=<filepath>`

### Requirement: CLI syntax reference
The skill SHALL document the Obsidian CLI parameter format: key-value pairs (`param=value`), boolean flags (bare words), quoting for spaces, `\n` for newlines, and `file=` vs `path=` targeting.

#### Scenario: Agent creates a note with content
- **WHEN** the agent needs to create a new note
- **THEN** it runs `obsidian vault=brain create name="Note Title" content="# Heading\n\nBody" silent`

### Requirement: Common operation patterns
The skill SHALL include example commands for: read, create, append, prepend, search, delete, daily note operations, property read/set, list files, backlinks, and tags.

#### Scenario: Agent appends to daily note
- **WHEN** the agent needs to add content to today's daily note
- **THEN** it runs `obsidian vault=brain daily:append content="<content>"`

### Requirement: Silent failure workarounds
The skill SHALL document workarounds for known CLI silent failures where the CLI exits 0 but returns wrong or empty data. At minimum: `tasks all todo` instead of `tasks todo`, `tasks all` instead of `tasks`, `tags all counts` instead of `tags counts`, and `silent` flag on `create` commands.

#### Scenario: Agent lists vault tasks
- **WHEN** the agent needs to list open tasks
- **THEN** it runs `obsidian vault=brain tasks all todo format=json` (not `tasks todo`)

#### Scenario: Agent creates a note without opening GUI
- **WHEN** the agent creates a note via CLI
- **THEN** it includes the `silent` flag to prevent Obsidian from opening the note in the GUI

### Requirement: Heading-level edit recipe
The skill SHALL document how to use `obsidian eval` with JavaScript to replace, append, or prepend content under a specific heading. The JS pattern SHALL find the heading line, determine section boundaries by heading level, and modify only that section.

#### Scenario: Agent replaces content under a heading
- **WHEN** the agent needs to update the "Aktueller Stand" section of a note
- **THEN** it constructs a JS snippet using `eval` that targets that heading and replaces its content, leaving other sections intact

### Requirement: Command discovery directive
The skill SHALL instruct agents to run `obsidian help` or `obsidian help <command>` to discover commands not explicitly listed in the skill, rather than attempting to enumerate all 100+ CLI commands.

#### Scenario: Agent needs an uncommon operation
- **WHEN** the agent needs to perform a vault operation not covered in the skill's examples
- **THEN** it runs `obsidian help` to discover the correct command and syntax

### Requirement: Obsidian must be running
The skill SHALL state upfront that the CLI requires a running Obsidian instance and will hang or fail if Obsidian is not open.

#### Scenario: CLI fails because Obsidian is closed
- **WHEN** the agent calls the CLI and it times out or returns an IPC error
- **THEN** the agent informs the user to open Obsidian and retry
