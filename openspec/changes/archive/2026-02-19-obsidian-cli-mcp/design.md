## Context

The dotfiles repo currently has a Python MCP server at `mcp-servers/obsidian-cli-mcp/` that wraps the Obsidian CLI (v1.12+) via subprocess. It uses FastMCP, has 16 tool definitions, and is launched through a wrapper script. This works but adds layers: Python → subprocess → CLI → IPC → Obsidian. The CLI itself has documented reliability issues (silent failures, hangs when Obsidian is unresponsive).

Both Claude Code and Cursor have direct shell access, so agents can call `obsidian` commands via Bash without needing an MCP intermediary. kepano's obsidian-skills repo demonstrates this pattern with a `SKILL.md` file that teaches agents the CLI syntax.

No `.cursor/` directory or rules exist in the repo yet. Claude Code already has `.claude/skills/` from the OpenSpec init.

## Goals / Non-Goals

**Goals:**
- Replace the MCP server with a single `SKILL.md` that works in Claude Code
- Add equivalent Cursor rules for the same CLI capability
- Document workarounds for known CLI silent failures directly in the skill
- Preserve the heading-edit pattern (currently in `heading_patch.py`) as documented `eval` recipes
- Clean removal of all MCP server code, config, and wrapper scripts

**Non-Goals:**
- Claude Desktop support (no shell access, user doesn't use it)
- Wrapping every CLI command — the skill should teach the agent to use `obsidian help` for discovery
- Building a comprehensive test suite for the CLI itself (Obsidian's responsibility)
- Publishing to the Claude Code marketplace (this is a personal dotfiles repo)

## Decisions

### 1. Skill file location: `.claude/skills/obsidian-cli/SKILL.md`

Follow the Agent Skills specification and Claude Code's discovery mechanism. Skills in `.claude/skills/` are automatically discovered at startup via frontmatter, then loaded on-demand when relevant.

**Alternative considered**: Copying kepano's skill verbatim. Rejected because our version needs vault-specific config (`vault=brain`), silent failure workarounds, and heading-edit recipes that kepano's generic skill doesn't include.

### 2. Cursor rules: `.cursor/rules/obsidian-cli.mdc`

Cursor uses `.cursor/rules/` with `.mdc` files (Markdown with YAML frontmatter). Each rule file has a `description` field for auto-triggering and `globs` for file-pattern matching. This mirrors how Claude Code skills work — agent reads instructions and uses shell access.

**Alternative considered**: `.cursorrules` (single flat file at repo root). Rejected because `.cursor/rules/` supports multiple modular rule files and auto-triggering via description, which is the modern Cursor convention.

### 3. Skill content: reference-style, not exhaustive

The skill should teach the agent *how to use the CLI* rather than listing every command. Key sections:
- Syntax and parameter format
- Vault targeting (`vault=brain` default)
- Common patterns (read, create, append, search, daily notes, properties)
- Silent failure workarounds (the critical 13 — documented as a "Gotchas" section)
- Heading-edit recipe via `eval` (translated from `heading_patch.py`)
- Directive to run `obsidian help` for full command discovery

This keeps the skill under 500 lines (recommended limit) and avoids going stale when the CLI adds new commands.

### 4. Clean removal of MCP server

Delete the entire `mcp-servers/obsidian-cli-mcp/` directory, the wrapper script, the MCP settings entry, and the Makefile target. Update `doctor-mcp` to check for the `obsidian` CLI binary presence instead of the MCP server venv.

**Alternative considered**: Keeping the MCP server as a fallback. Rejected because maintaining two approaches adds confusion and the MCP server has unresolved timeout issues tied to the CLI's IPC model.

## Risks / Trade-offs

**Agent may misuse CLI syntax** → The skill documents exact syntax with examples. The agent can also run `obsidian help <command>` for self-correction.

**Silent failures still affect skill-based approach** → True, but the skill documents workarounds inline. An agent reading "use `tasks all todo` not `tasks todo`" is more transparent than a Python wrapper silently fixing things.

**Cursor rules format may change** → `.cursor/rules/` is the current convention. If it changes, only one `.mdc` file needs updating.

**No Obsidian access when app is closed** → Same limitation as the MCP approach — the CLI requires a running Obsidian instance. The skill should note this upfront.

**Heading edits via `eval` are fragile** → The JS template assumes standard Markdown headings. Edge cases (HTML headings, deeply nested) may fail. This is unchanged from the MCP approach — just documented differently.
