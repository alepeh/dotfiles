---
name: sdlc:continue
description: Continue working on a change by creating the next missing artifact in sequence. Use when progressing a change step-by-step — one artifact per invocation, with architecture context read before each.
---

Continue working on a change by creating the next missing artifact. One
artifact per invocation, in the sequence required for the change's type.

Read the **change-protocol** skill for the per-type artifact sequence and
templates.

**Input**: Optionally a change name. If omitted, infer from conversation
context or prompt.

## Steps

### 1. Select the change

If no name provided:
- List active changes: `ls <changes_dir>/` (excluding `archive/`)
- If only one active, auto-select
- If multiple, use **AskUserQuestion** to pick

Read `<changes_dir>/<name>/meta.yaml` to get the type.

### 2. Determine artifact sequence and find the next one

Per the type's sequence (from **change-protocol** skill), check which
artifacts exist (non-empty) in the change directory. The next artifact in
sequence that doesn't exist yet is what we create.

**If all required artifacts exist:** inform the user. Suggest `/sdlc:apply` to
implement, or `/sdlc:verify` + `/sdlc:archive` if already implemented.

### 3. Read context

- Read all existing artifacts in this change directory
- Read `<rules_file>` and `<guidelines>`
- If creating `design.md` or `specs/`: also read `<domain_model>`

### 4. Create the next artifact

Use the templates from the **change-protocol** skill.

**Special handling for `specs/`** (feature type only):
- Read the proposal's Capabilities section
- Create one `specs/<capability>/spec.md` per capability
- Use delta-spec format with `## ADDED Requirements`

**Special handling for `design.md`:**
After writing, run the domain-impact checklist (9 items from
**change-protocol** skill). Update `meta.yaml`:
- `domain_impact: none | additive | breaking`
- `domain_changes:` list
- If impact is `additive` or `breaking`, note that `<domain_model>` needs
  updating before implementation

### 5. Show progress

Count artifacts: done / total for this type.

## Output

```
## Created: <artifact-name>

**Change:** <name> (<type>)
**Progress:** N/M artifacts complete
**Next:** <next artifact | "all artifacts complete — ready for /sdlc:apply">
```

## Guardrails

- Create ONE artifact per invocation (that's the point — `/sdlc:ff` is for
  batch)
- Always read existing artifacts before creating a new one
- Never skip artifacts or create out of order
- If context is unclear, ask before creating
- Run the domain-impact checklist when creating `design.md`
