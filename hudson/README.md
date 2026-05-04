# Hudson (dotfiles wiring)

Hudson is a work-assistant agent. **Everything that defines Hudson lives in the
Obsidian vault** — skill body, slash-command wrapper, runtime knowledge:

```
$HUDSON_VAULT/.cursor/skills/hudson/SKILL.md          # persona + invocation
$HUDSON_VAULT/.claude/commands/hudson.md              # /hudson slash-command wrapper
$HUDSON_VAULT/agents/hudson/{commitments,memory,playbook,patterns,…}.md
```

This directory holds **only** the install/uninstall scripts and a docs file
explaining the calendar export flow. There is no source code or skill body
here — anything else would be a second source of truth.

## Vault path resolution

`HUDSON_VAULT` is the canonical env var across **all** Hudson tooling:

- This wiring (`scripts/install-hudson.sh`)
- Vault-resident agent skills (`scripts/link-vault-skills.sh`)
- The Hudson Obsidian plugin's Python backend

Resolution order (first hit wins):

1. `$HUDSON_VAULT`
2. `$ZK_VAULT` — legacy fallback for older setups, prints a deprecation
   warning and recommends migration. Will keep working indefinitely.
3. `~/code/zettelkasten` — the default checkout location.

## Install

```
make hudson-install
```

Creates these symlinks (all pointing into the vault):

| Link | Target |
|---|---|
| `~/.claude/skills/hudson` | `<vault>/.cursor/skills/hudson` |
| `~/.claude/commands/hudson.md` | `<vault>/.claude/commands/hudson.md` |
| `~/.cursor/skills/hudson` | `<vault>/.cursor/skills/hudson` |

Also appends `export HUDSON_VAULT=…` and `export HUDSON_CALENDAR_DIR=…` to
`~/.zshrc.local` if missing. If `ZK_VAULT` is already exported there, it's
left alone for backward compat with other Zettelkasten tooling that reads
that variable.

After running this, `/hudson` works in any terminal that has `claude` or
`agent` on `$PATH`, regardless of the current working directory.

## Relationship to the Hudson Obsidian plugin

The [Hudson plugin](https://github.com/alepeh/hudson) is the in-Obsidian
companion. It consumes the **same** vault files this script wires up:

- The plugin's chat surfaces `/hudson` as a slash command by walking both
  `<vault>/.claude/commands/*.md` and `<vault>/agents/<name>/commands/*.md`.
- The plugin's skill picker lists every `*.md` under `<vault>/agents/<name>/`
  (plus one level of useful sub-directories), filtered through
  `<vault>/agents/registry.yaml` if present so dispatched-only specialists
  stay hidden.
- The plugin's Python backend resolves the vault path from `$HUDSON_VAULT`
  using the exact same resolution chain documented above.

So this wrapper and the plugin are not competitors — they expose the
same agent through two different surfaces (terminal vs. Obsidian sidebar).
You can install one, the other, or both.

## Uninstall

```
make hudson-uninstall
```

Removes the three links above. Leaves the vault contents (including memory
files) untouched.

## Requirements

- The vault must be cloned at the location `$HUDSON_VAULT` resolves to
  (default `~/code/zettelkasten`).
- Obsidian **Tasks** plugin enabled in the vault (Hudson's commitment layer uses its checkbox syntax).
- Outlook calendar export populated by a Power Automate scheduled flow — see [docs/calendar-export-flow.md](docs/calendar-export-flow.md). Default path: `~/Library/CloudStorage/OneDrive-Paysafe/meeting_export/`, overridable via `HUDSON_CALENDAR_DIR`.
- `make hudson-install` is idempotent and safe to re-run.
