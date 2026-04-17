---
name: sdlc:archive
description: Archive a completed change — run the rule-distillation prompt, sync delta specs into main specs, set completed date, move to archive/YYYY-MM-DD-<name>. Supports single or batch archiving. Use once implementation is done and /sdlc:verify passes.
---

Archive one or more completed changes. Runs the DISTILL step, syncs delta
specs into main specs via intelligent merge, and moves the change to
`archive/`. Read the **change-protocol** skill for the rule format, delta-spec
grammar, and merge semantics.

**Input**: Optionally a change name, or `all` for batch. If omitted, prompt.

## Steps

### 1. Select change(s)

List active changes: `ls <changes_dir>/` (excluding `archive/`)

If no active changes: inform and stop.

**If input is `all` or user wants batch:**
- Show all active changes with status (type, tasks complete/total)
- Use **AskUserQuestion** to confirm selection
- Process each through steps 2-6

**If single:** use provided name or prompt.

### 2. Check readiness

For each selected change:

**a. Read `meta.yaml`** for type and domain impact.

**b. Check task completion** — read `tasks.md`, count `- [ ]` vs `- [x]`.
   If incomplete tasks: warn and ask to confirm (don't hard-block — the user
   may have archived intentionally).

**c. Check artifact completion** — verify expected artifacts exist per type.

**d. Recommend running `/sdlc:verify` first** if it hasn't been run this
   session. Don't re-run it here — verify is its own command.

### 3. DISTILL rules — the critical step

For each change, ask:

> Before archiving **<name>**, let's check — did this change reveal anything
> worth capturing as a rule?
>
> - **Mistakes avoided**: What almost went wrong?
> - **Patterns discovered**: What approach worked well?
> - **Assumptions broken**: What did we learn about the domain?
> - **Debt identified**: What shortcut was taken deliberately?
>
> If nothing stands out, just say 'none' and we'll proceed.

If the user identifies rules:
- Add each to `<rules_file>` with the next R-NNN ID (source = change name)
- Update `meta.yaml` `rules_distilled:` list
- Use the format from the **change-protocol** skill:
  ```
  ### R-NNN: Rule title
  **Source:** <change-name>
  **Rule:** <the rule>
  **Why:** <the reason>
  ```

If a finding is significant enough for an ADR, offer to create one in
`<decisions_dir>/` using the ADR template from the **change-protocol** skill.

### 4. Sync delta specs

Check for delta specs at `<changes_dir>/<name>/specs/`. If none, skip.

If delta specs exist, apply them to main specs via **intelligent merge**:

- Read the delta spec and the corresponding main spec at
  `<specs_dir>/<capability>/spec.md`
- Apply changes per the delta-spec grammar (defined in **change-protocol**
  skill):
  - **ADDED Requirements** → add to main spec (or create new spec file)
  - **MODIFIED Requirements** → update in main spec, preserving unchanged
    content
  - **REMOVED Requirements** → remove from main spec
  - **RENAMED Requirements** → rename in main spec

**For batch mode with conflicts** (2+ changes touch the same capability):
- Read delta specs from each conflicting change
- Search the codebase for implementation evidence
- Apply in chronological order (older first)
- Note conflicts and resolutions in the output

### 5. Update `meta.yaml`

Set `completed: <today YYYY-MM-DD>`.

### 6. Move to archive

```bash
mkdir -p <changes_dir>/archive
mv <changes_dir>/<name> <changes_dir>/archive/YYYY-MM-DD-<name>
```

If the target already exists, fail with an error for that change (don't
clobber history).

### 7. Show summary

## Output (single)

```
## Archived: <name>

**Type:** <type>
**Archived to:** <changes_dir>/archive/YYYY-MM-DD-<name>/
**Specs synced:** Yes (N requirements) | No delta specs | Skipped
**Rules distilled:** R-NNN, R-NNN | none
```

## Output (batch)

```
## Batch Archive Complete

Archived N changes:
- <name-1> → archive/YYYY-MM-DD-<name-1>/ (specs synced, 1 rule)
- <name-2> → archive/YYYY-MM-DD-<name-2>/ (no specs)

Spec sync summary:
- N delta specs synced to main specs
- M conflicts resolved

Rules distilled:
- R-NNN: <title> (from <name-1>)
```

## Guardrails

- Always run DISTILL before archiving — this is the learning step
- Always prompt for change selection if not provided
- Don't hard-block archive on warnings — inform and confirm
- Sync specs intelligently (partial updates, not wholesale replacement)
- For batch: detect spec conflicts early, resolve by checking codebase
- Update `meta.yaml` (`completed`, `rules_distilled`) BEFORE moving
- Never clobber an existing archive directory — fail loudly instead
