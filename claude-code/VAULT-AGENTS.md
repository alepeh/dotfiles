# Vault-Resident Agents

A pattern for keeping AI agent definitions, knowledge, and persistent memory in an Obsidian vault while still making them available to the Claude CLI from any directory on the machine. Designed for a single user with one or more long-lived "specialist" agents (productivity coach, expense bookkeeper, work-context dispatcher, etc.) — not a multi-tenant system.

## Why

Three things tend to drift apart in agent setups:

1. **The recipe** — the markdown that tells Claude how to behave (slash command file).
2. **The knowledge** — what the agent knows about your domain, your patterns, your past decisions.
3. **The memory** — what happened in past sessions, what's still open, what got deferred.

When these live in three different places (e.g. recipe in a dotfiles repo, knowledge in a wiki, memory in a SQLite file) the agent feels split-brained and onboarding a new machine is fiddly. This pattern collapses all three into one place: a folder per agent in your Obsidian vault.

## The pattern

```
<vault>/agents/<name>/
  commands/         # Slash command files exposed to Claude CLI (optional)
  agent.md          # Identity, capabilities, integrations
  playbook.md       # Learned rules, preferences, anti-patterns
  memory.md         # Active state, recent session log
  skills.md         # What tools the agent uses, how it's dispatched
  patterns.md       # Derived insights from accumulated sessions (optional)
  archive/          # Monthly archives of trimmed memory (optional)
```

The agent's slash command file (in `commands/`) gets symlinked into `~/.claude/commands/`, so typing `/<name>` in any Claude CLI session triggers it. Everything else is read and written by the agent at runtime through the Obsidian CLI (which talks to the running Obsidian instance over IPC).

The result: one folder = one agent. Edit `playbook.md` in Obsidian and the next session sees the new rule. Move to a new machine with the vault synced and the agent comes with it.

## Setup on a new machine

```bash
# 1. Clone dotfiles + run the standard installer
git clone git@github.com:<you>/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && make install

# 2. Sync your Obsidian vault (however you sync it — iCloud, Syncthing, git, etc.)
#    By default the script looks at ~/obsidian/brain. Override per-machine:
export HUDSON_VAULT=/path/to/your/vault   # add to ~/.zshrc.local

# 3. Open Obsidian once with that vault so its registry knows about it.
#    The Obsidian CLI uses Obsidian's own vault registry, not a path lookup.

# 4. Mirror the vault's agent commands into ~/.claude/commands/
make link-vault-skills
```

That's the whole onboarding. From here, `/hudson` (or whatever your agent is named) works in any terminal that runs `claude`.

## Wiring: two halves

| Half | What it does | Where it lives |
|---|---|---|
| **Recipe sync** | Symlinks `<vault>/agents/<name>/commands/*.md` into `~/.claude/commands/` so the Claude CLI sees them as user-level slash commands | `scripts/link-vault-skills.sh` (in dotfiles), wired as `make link-vault-skills` |
| **State access** | The agent reads/writes its memory and playbook through the Obsidian CLI, which IPCs to a running Obsidian instance and resolves vault names against Obsidian's own registry | `obsidian-cli` skill (in `~/.claude/skills/obsidian-cli/SKILL.md`); requires Obsidian to be open |

Because state access goes through the Obsidian app's IPC, the agent reaches the same vault regardless of where Claude was launched from — your terminal in `/tmp`, a Claude Code session in some unrelated repo, all of them write to the same `agents/<name>/memory.md`. There is no per-process vault path to thread through.

## Configuration surface

| Variable | Default | Purpose |
|---|---|---|
| `HUDSON_VAULT` | `~/obsidian/brain` | Path to the vault whose `agents/` directory should be mirrored. Set in `~/.zshrc.local` for per-machine overrides. |

That's it for this pattern's own config. Everything else (MCP credentials, etc.) is independent.

### Single vault vs multi-vault

The current `link-vault-skills` script walks **one** vault. If you keep separate vaults per context (e.g. a work vault and a personal vault), you have two clean options:

- **One vault is the agents-host, the other is just data.** Pick the vault whose `agents/` directory you want exposed; set `HUDSON_VAULT` to it. Agents can still reference the other vault by passing `vault=<other-name>` to the Obsidian CLI (any vault registered in Obsidian's app registry is reachable).
- **Both vaults host agents.** Run the script twice with different `HUDSON_VAULT` values. Be aware: the prune step is per-run, so each invocation only prunes links pointing into the vault it just walked — links from the other vault are untouched. Naming collisions (same `commands/foo.md` in two vaults) are last-write-wins.

For most setups, option one is enough. Adopt option two if you really need separate command sets per context.

## MCP servers — the agents' tools

The vault-resident-agent pattern is orthogonal to which MCP servers the agent uses. Wiring MCP credentials happens once via `make claude-code-mcp` and `~/.env.mcp` (see the main README's MCP setup section). Once an MCP is registered globally in `~/.claude.json`, any agent's recipe can reference its tools.

Three concrete examples of agent ↔ MCP pairings, matching the situations this dotfiles repo's owner actually runs:

### Personal productivity (Todoist + Gmail + Calendar)

- **MCPs:** `todoist`, `mcp-gsuite`, `obsidian-cli`
- **Agent recipe** lives at `<vault>/agents/<name>/commands/<name>.md` and references those MCPs by their tool prefixes (`mcp__todoist__find-tasks`, `mcp__mcp-gsuite__query_gmail_emails`, etc.)
- **State** in `<vault>/agents/<name>/memory.md` (active commitments, recent sessions)

### Work context (Atlassian — Jira + Confluence)

- **MCP:** Anthropic publishes a hosted Atlassian MCP at `https://mcp.atlassian.com/v1/sse` (OAuth via the CLI's first-run browser flow). Add via:
  ```bash
  claude mcp add --scope user --transport sse atlassian https://mcp.atlassian.com/v1/sse
  claude mcp list   # complete OAuth in the browser
  ```
- **Agent recipe** does the equivalent of "show me everything assigned to me, group by status" via Jira tools (`mcp__atlassian__search-issues`, `mcp__atlassian__get-issue`, etc.)
- **State** still in the vault — even if the agent is work-flavoured, its memory of "what you were working on yesterday" persists alongside the personal agent's memory.
- **Caveat:** if your work machine's policy forbids personal cloud sync, run a separate vault for work and set `HUDSON_VAULT` accordingly per machine.

### Plain Obsidian tasks (no external task system)

- **MCP:** `mcp-obsidian` (already wired in this repo) gives the agent vault read/write/search via the Obsidian Local REST API plugin. Tasks then are just markdown checkboxes in your notes — the agent searches by tag, by frontmatter property, or by content.
- **Tooling pairing:** the `obsidian-cli` skill is a higher-level layer on top of the same Obsidian — prefer it for typed operations (`obsidian vault=<name> tasks list status=open`) and `mcp-obsidian` for raw read/write.
- **Trade-off:** no notification triggers (no equivalent of Todoist's "tasks due today" push). Your agent has to fetch and rank on every session.

These three are not exhaustive — the pattern works with any MCP. Linear, Notion, GitHub Issues, custom in-house servers all slot in the same way: register the MCP once in `~/.claude.json`, reference it from the agent's recipe.

## Adapting the pattern

The hard-coded conventions are minimal and most are easy to change:

| Convention | Where it's set | If you want to change it |
|---|---|---|
| Vault path defaults to `~/obsidian/brain` | `scripts/link-vault-skills.sh` | Set `HUDSON_VAULT` instead of editing the script |
| Slash commands sourced from `agents/*/commands/*.md` | Same script | Edit the glob if your layout differs |
| Symlinks land in `~/.claude/commands/` | Same script | Hard to change without confusing Claude CLI; don't |
| Agent file set (`agent.md`, `playbook.md`, `memory.md`, etc.) | Convention only — Claude reads whatever the recipe references | Use any structure you like; the script doesn't care |

Want a single-purpose journaling agent instead of a productivity coach? Make `agents/journal/commands/journal.md` the recipe, give it a one-line `playbook.md`, no `memory.md` (let it append to dated notes instead). The pattern is the wiring, not the prescription.

## Limitations / not included

- **Single user.** No multi-tenant isolation, no per-user secrets. The agent reads `~/.env.mcp` like any other Claude CLI session.
- **Requires Obsidian to be open** for runtime state access (the `obsidian` CLI is IPC, not file-system). If Obsidian is closed, the agent can read its own recipe (which lives on disk) but can't update memory.
- **No background scheduling.** Agents run when invoked. For "wake me up at 7:30 with a brief", combine with launchd / cron + the `claude -p` non-interactive mode (see CHIEF-OF-STAFF.md "Phase 2" for an example).
- **No multi-machine state sync of its own.** Vault sync is whatever you already use (iCloud, Syncthing, git, etc.). The pattern just inherits whatever consistency that gives you.

## Related docs

- [CHIEF-OF-STAFF.md](CHIEF-OF-STAFF.md) — concrete agent built on this pattern: morning brief + evening recap commands that integrate Gmail, Calendar, Todoist, Obsidian.
- [SDLC scaffolding](sdlc/) — separate pattern for personal-project software development; not vault-resident, but also Claude-CLI-based.
