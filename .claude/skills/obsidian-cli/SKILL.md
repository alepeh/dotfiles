---
name: obsidian-cli
description: Interact with the Obsidian vault using the Obsidian CLI to read, create, search, and manage notes, tasks, properties, daily notes, and more. Use when the user asks to interact with their Obsidian vault, manage notes, search vault content, or perform vault operations.
---

# Obsidian CLI

Use the `obsidian` CLI to interact with a running Obsidian instance. The CLI communicates via IPC — **Obsidian must be open** or commands will hang/timeout. If a command hangs, ask the user to open Obsidian and retry.

Run `obsidian help` to see all available commands. Run `obsidian help <command>` for detailed usage of a specific command. The CLI has 100+ commands — this skill covers the most common patterns. Always use `obsidian help` for commands not listed here.

Full docs: https://help.obsidian.md/cli

## Vault conventions

Before interacting with the vault, read the conventions file:

```bash
obsidian vault=brain read path="Agent Instructions.md"
```

This file contains the directory structure, note types with frontmatter schemas, naming conventions, tag taxonomy, linking rules, and special syntax. Use it to:
- **Write ops**: Follow schemas exactly when creating or editing notes
- **Read/search ops**: Know where to look (e.g., people are in `notes/` tagged `people`, journals are in `journals/` as `YYYY-MM-DD.md`, recipes are in `meals/`) and how to filter by `collections`, `tags`, or type-specific properties

## Vault targeting

Always target the vault as the first parameter:

```bash
obsidian vault=brain <command> [parameters] [flags]
```

## Syntax

**Parameters** use `key=value`. Quote values with spaces:

```bash
obsidian vault=brain create name="My Note" content="Hello world"
```

**Flags** are bare boolean words with no value:

```bash
obsidian vault=brain create name="My Note" silent overwrite
```

**Newlines** use `\n`, **tabs** use `\t`:

```bash
obsidian vault=brain append file="My Note" content="# Title\n\nBody text"
```

## File targeting

- `file=<name>` — resolves like a wikilink (name only, no path or extension needed)
- `path=<path>` — exact path from vault root (e.g., `folder/note.md`)

Without either, the active file in Obsidian is used.

## Common patterns

### Read and write

```bash
obsidian vault=brain read path=notes/MyNote.md
obsidian vault=brain create name="New Note" content="# Hello" silent
obsidian vault=brain create name="New Note" template="Template Name" silent
obsidian vault=brain append path=notes/MyNote.md content="Appended line"
obsidian vault=brain prepend path=notes/MyNote.md content="Prepended line"
obsidian vault=brain delete path=notes/OldNote.md
obsidian vault=brain move file="My Note" to=Archive/
```

### Search

```bash
obsidian vault=brain search query="search term" format=json
obsidian vault=brain search query="search term" limit=10
```

### Daily notes

```bash
obsidian vault=brain daily:read
obsidian vault=brain daily:append content="- [ ] New task"
obsidian vault=brain daily:prepend content="## Morning\n\nNotes here"
obsidian vault=brain daily:path
```

### Properties (frontmatter)

```bash
obsidian vault=brain properties path=notes/MyNote.md format=tsv
obsidian vault=brain property:set name="status" value="done" file="My Note"
obsidian vault=brain property:remove name="draft" file="My Note"
```

### Files and navigation

```bash
obsidian vault=brain files format=json
obsidian vault=brain files folder=notes ext=md format=json
obsidian vault=brain backlinks file="My Note" format=json
obsidian vault=brain links file="My Note" format=json
obsidian vault=brain orphans format=json
```

### Tags and tasks

```bash
obsidian vault=brain tags all counts
obsidian vault=brain tag name=projects format=json
obsidian vault=brain tasks all todo format=json
obsidian vault=brain tasks all format=json
```

### Eval (arbitrary JavaScript)

```bash
obsidian vault=brain eval code="app.vault.getFiles().length"
```

## Output formats

Use `format=` on most commands: `json`, `csv`, `tsv`, `md`, `paths`, `text`, `tree`, `yaml`.

Use `--copy` to copy output to clipboard. Use `total` on list commands to get a count.

## Gotchas — silent failure workarounds

The CLI has known issues where it exits 0 but returns wrong or empty data. Use these workarounds:

| Command | Problem | Use instead |
|---------|---------|-------------|
| `tasks todo` | Returns 0 results (scoped to nonexistent active file) | `tasks all todo` |
| `tasks` | Same scoping issue | `tasks all` |
| `tags counts` | Reports no tags found | `tags all counts` |
| `properties format=json` | Returns YAML instead of JSON | `properties format=tsv` |
| `create name="x" content="y"` | Opens GUI, steals focus | Add `silent` flag |
| `create path="a/b/c.md"` | Fails if parent folders don't exist | Use `name=` or create folders first |

Always add `silent` when creating notes to prevent Obsidian from opening the note in the GUI.

## Heading-level edits via eval

To replace, append, or prepend content under a specific heading without affecting the rest of the file, use `obsidian eval` with this JavaScript pattern.

**Replace content under a heading:**

```bash
obsidian vault=brain eval code='(async () => {
  const filepath = "notes/MyNote.md";
  const heading = "Aktueller Stand";
  const newContent = "Projekt läuft planmäßig.";
  const file = app.vault.getAbstractFileByPath(filepath);
  if (!file) throw new Error("File not found: " + filepath);
  const text = await app.vault.read(file);
  const lines = text.split("\n");
  const hRe = /^(#{1,6})\s+(.+)$/;
  let hStart = -1, hLevel = 0, sEnd = lines.length;
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(hRe);
    if (m) {
      if (hStart === -1 && m[2].trim() === heading) {
        hStart = i; hLevel = m[1].length;
      } else if (hStart !== -1 && m[1].length <= hLevel) {
        sEnd = i; break;
      }
    }
  }
  if (hStart === -1) throw new Error("Heading not found: " + heading);
  const nl = [...lines.slice(0, hStart + 1), newContent, ...lines.slice(sEnd)];
  await app.vault.modify(file, nl.join("\n"));
  return "OK";
})()'
```

Adapt the pattern for **append** (insert before `sEnd`) or **prepend** (insert after `hStart + 1`). The script finds the heading, determines the section boundary by heading level, and modifies only that range.
