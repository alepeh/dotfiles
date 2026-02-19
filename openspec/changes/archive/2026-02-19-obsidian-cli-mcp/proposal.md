## Why

The community `mcp-obsidian` server (via Obsidian REST API plugin) was being replaced by a Python MCP wrapper around the official Obsidian CLI (v1.12+). But the MCP approach adds unnecessary complexity — a Python server with subprocess calls, FastMCP dependency, wrapper scripts, and timeout issues — when the agents (Claude Code, Cursor) can call the CLI directly via their shell tools.

kepano's [obsidian-skills](https://github.com/kepano/obsidian-skills) demonstrates the simpler approach: a markdown skill file that teaches agents how to use the CLI. This works across Claude Code and Cursor without any server infrastructure. Since Claude Desktop (which lacks shell access) is not in use, MCP is unnecessary overhead.

## What Changes

- **Replace MCP server with Agent Skill** — delete the Python MCP server (`mcp-servers/obsidian-cli-mcp/`) and create a `SKILL.md` that teaches agents to use the Obsidian CLI directly. Include workarounds for the 13+ documented silent failures (e.g., use `tasks all todo` not `tasks todo`, add `silent` flag to `create`).
- **Add Cursor rules equivalent** — create a Cursor rules file with the same CLI instructions so both tools have Obsidian access.
- **Remove MCP configuration** — remove the `mcp-obsidian` entry from `claude-code/settings.json`, the wrapper script, and Makefile targets that install/manage the MCP server.
- **Keep heading-patch logic as a skill reference** — the `heading_patch.py` JS generation pattern is useful for heading-level edits via `eval`. Translate it to documented patterns in the skill file rather than discarding it.

## Capabilities

### New Capabilities
- `obsidian-skill`: Agent Skill file for Claude Code (`.claude/skills/obsidian-cli/SKILL.md`) with CLI reference, common patterns, workarounds for silent failures, and heading-edit recipes
- `cursor-rules`: Cursor rules file with equivalent Obsidian CLI instructions
- `mcp-cleanup`: Remove MCP server code, wrapper script, settings entries, and Makefile targets

### Modified Capabilities

## Impact

- **Delete**: `mcp-servers/obsidian-cli-mcp/` (entire directory — server, tests, venv, lock file)
- **Delete**: `mcp-wrappers/obsidian-wrapper.sh`
- **Create**: `.claude/skills/obsidian-cli/SKILL.md`
- **Create**: Cursor rules file (location TBD — `.cursor/rules/` or `.cursorrules`)
- **Modify**: `claude-code/settings.json` — remove `mcp-obsidian` entry
- **Modify**: `Makefile` — remove `obsidian-mcp` target, update `doctor-mcp` to check for CLI instead of MCP server
- **Modify**: `README.md` — update MCP server table, add skill-based Obsidian access docs
