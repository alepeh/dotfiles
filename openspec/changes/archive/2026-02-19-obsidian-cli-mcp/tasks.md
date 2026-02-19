## 1. Create Claude Code Skill

- [x] 1.1 Create `.claude/skills/obsidian-cli/SKILL.md` with YAML frontmatter (`name: obsidian-cli`, `description` field for activation)
- [x] 1.2 Write CLI syntax section: parameter format (`key=value`), boolean flags, quoting, `\n`/`\t`, `file=` vs `path=` targeting
- [x] 1.3 Write vault targeting section: default `vault=brain` on all commands
- [x] 1.4 Write common patterns section: read, create (with `silent`), append, prepend, search, delete, daily ops, property read/set, list files, backlinks, tags
- [x] 1.5 Write silent failure workarounds section: `tasks all todo`, `tasks all`, `tags all counts`, `silent` on create, `properties format=tsv`
- [x] 1.6 Translate `heading_patch.py` JS pattern into a documented heading-edit recipe using `obsidian eval`
- [x] 1.7 Add command discovery directive: `obsidian help` / `obsidian help <command>`
- [x] 1.8 Add prerequisite note: Obsidian must be running, CLI hangs if app is closed

## 2. Create Cursor Rules

- [x] 2.1 Create `.cursor/rules/` directory
- [x] 2.2 Create `.cursor/rules/obsidian-cli.mdc` with YAML frontmatter (`description` field for auto-triggering)
- [x] 2.3 Port CLI instructions from the Claude Code skill to Cursor rules format (same content, `.mdc` wrapper)

## 3. Remove MCP Server

- [x] 3.1 Delete `mcp-servers/obsidian-cli-mcp/` directory (source, tests, venv, lock, Makefile)
- [x] 3.2 Delete `mcp-wrappers/obsidian-wrapper.sh`
- [x] 3.3 Remove `mcp-obsidian` entry from `claude-code/settings.json` (keep other servers intact)

## 4. Update Makefile

- [x] 4.1 Remove `obsidian-mcp` target from Makefile
- [x] 4.2 Update `doctor-mcp` to check for `obsidian` CLI binary instead of MCP server venv
- [x] 4.3 Remove `obsidian-wrapper.sh` from the wrapper scripts check loop in `doctor-mcp`
- [x] 4.4 Update `.PHONY` declaration to remove `obsidian-mcp`

## 5. Verify

- [x] 5.1 Run `make help` and confirm `obsidian-mcp` target is gone
- [x] 5.2 Run `make doctor-mcp` and confirm it checks for `obsidian` CLI binary
- [x] 5.3 Verify `.claude/skills/obsidian-cli/SKILL.md` is discovered by Claude Code (restart session, check skill list)
- [x] 5.4 Test a CLI command via skill: `obsidian vault=brain read path=notes/Dotfiles.md`
