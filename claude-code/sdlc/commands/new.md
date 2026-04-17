---
name: sdlc:new
description: Start a new change — classify it (feature/enhancement/bugfix/ux/refactor/infra/data/docs), create the change directory with meta.yaml, and show the first artifact template. Use when beginning a new piece of work in an SDLC-bootstrapped project.
---

Start a new change using the architecture change protocol. Read the
`change-protocol` skill before acting — it defines the 8 types, the required
artifacts per type, the domain-impact checklist, and the `meta.yaml` schema.

**Input**: A change name (kebab-case) OR a description of what to build.

## Steps

### 1. If no clear input, ask what they want to build

Use the **AskUserQuestion tool** (open-ended, no preset options):
> "What change do you want to work on? Describe what you want to build or fix."

Derive a kebab-case name from the description.

**IMPORTANT:** Do NOT proceed without understanding what the user wants.

### 2. Classify the change

Read the **change-protocol** skill for the 8 change types. From the user's
description, determine:

```yaml
type: feature | enhancement | bugfix | ux | refactor | infra | data | docs
title: Short description
trigger: What prompted this change
```

If the type is ambiguous, use **AskUserQuestion** to confirm.

### 3. Create the change directory

```bash
mkdir -p changes/<name>/specs
```

(The `specs/` subdir is only used by `feature`-type changes; creating it
up-front is harmless.)

### 4. Read `.sdlc.yaml` config

Read the repo-root `.sdlc.yaml` to learn this project's `feature_groups` list
and path overrides. Two branches follow:

#### 4a. If `feature_groups` is non-empty

Use **AskUserQuestion** to ask:
> "Which feature group does this change belong to?"

Options: each entry in `feature_groups` plus `cross-cutting`.

Then open `<acceptance_dir>/<group>.md` and ask:
> "Which acceptance criteria does this change address? List existing AC IDs to
> flip to ✅, or new AC IDs you're introducing (e.g. `AC-<GROUP>-05`)."

For new ACs, append them to the acceptance file **before** implementation —
they define "done." Cross-cutting changes may legitimately have zero ACs;
record `acceptance_criteria: []` and note why in the proposal.

#### 4b. If `feature_groups` is empty

Skip the group + AC prompt. The `meta.yaml` still gets written but with
`feature_group: null` and `acceptance_criteria: null`. The AC gate in
`/sdlc:verify` will skip; add groups when the project grows enough to need
formal AC tracking.

### 5. Write `meta.yaml`

```yaml
type: <type>
title: <title>
trigger: <trigger>
created: <today YYYY-MM-DD>
feature_group: <group | null>
acceptance_criteria: <[AC-IDs] | [] | null>
domain_impact: null
domain_changes: []
rules_distilled: []
completed: null
```

### 6. Determine required artifacts

See the **change-protocol** skill's artifact matrix. Summary:

| Type        | Required artifacts                               |
|-------------|--------------------------------------------------|
| feature     | proposal.md, specs/, design.md, tasks.md         |
| enhancement | proposal.md, design.md, tasks.md                 |
| bugfix      | design.md (root cause), tasks.md                 |
| ux          | proposal.md (before/after), tasks.md             |
| refactor    | design.md (rationale), tasks.md                  |
| infra       | design.md (rationale), tasks.md                  |
| data        | design.md (migration plan + rollback), tasks.md  |
| docs        | Direct edit — no artifacts. Inform user and STOP |

### 7. Show the template for the first artifact

Pull the template from the **change-protocol** skill (it has the proposal.md
and design.md templates inline). Show it to the user but do NOT write it yet.

### 8. STOP and wait

## Output

```
## Change created: <name>

**Type:** <type>
**Feature group:** <group or "n/a — project has no groups yet">
**Location:** changes/<name>/
**Required artifacts:** <list>

### First artifact: <proposal.md | design.md>

<template shown inline>

Ready to create the first artifact? Describe what this change is about and
I'll draft it, or run `/sdlc:continue` to step through each artifact one at
a time.
```

## Guardrails

- Do NOT create any artifacts yet — just show the template for the first one
- Do NOT advance beyond the first-artifact template
- If the name is invalid (not kebab-case), ask for a valid name
- If a change with that name already exists, suggest `/sdlc:continue` instead
- Always write `meta.yaml` with the classified type
- If `.sdlc.yaml` is missing, the project wasn't bootstrapped — suggest `/sdlc:import` first
