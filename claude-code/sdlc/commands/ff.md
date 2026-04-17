---
name: sdlc:ff
description: Fast-forward — classify a change and generate ALL required artifacts in one go (proposal, specs, design, tasks). Ends with a ready-to-implement task list and domain-impact assessment filled in. Use when you want to go from idea to ready-to-code quickly without stepping through each artifact individually.
---

Fast-forward through change creation. Classify → create every required
artifact in sequence → run the domain-impact checklist → produce a
ready-to-implement task list, all in one invocation.

Read the **change-protocol** skill for the artifact matrix, templates, and
domain-impact checklist.

**Input**: A change name (kebab-case) OR a description of what to build.

## Steps

### 1. If no clear input, ask

Use **AskUserQuestion** (open-ended):
> "What change do you want to work on? Describe what you want to build or fix."

Derive a kebab-case name.

### 2. Classify

Pick the type (see **change-protocol** skill for descriptions). Confirm with
**AskUserQuestion** if ambiguous.

### 3. Create the change directory + skeletal `meta.yaml`

```bash
mkdir -p changes/<name>/specs
```

Write `meta.yaml` with `type`, `title`, `trigger`, `created`, `feature_group`,
`acceptance_criteria`, `domain_impact: null`, etc. See `/sdlc:new` step 5 for
the schema. Feature-group + AC logic follows `.sdlc.yaml` (skip if
`feature_groups: []`).

### 4. Read architecture context

Before writing any artifact, read:
- `<rules_file>` (default `architecture/rules.md`) — check if existing rules apply
- `<guidelines>` (default `architecture/guidelines.md`) — conventions to follow
- `<domain_model>` (default `architecture/domain-model.md`) — current state

These shape the proposal and design decisions.

### 5. Create artifacts in sequence based on type

Iterate in order (per the matrix). For each artifact:
- Read any previously created artifacts in this change for context
- Use the template from the **change-protocol** skill
- Write the file
- Show brief progress: "Created <artifact>"

**Spec files** (feature type only):
- Create one `specs/<capability>/spec.md` per capability listed in proposal
- Use delta-spec format with `## ADDED Requirements`
- Each requirement needs `### Requirement: <name>` + `#### Scenario: <name>`
  with WHEN/THEN
- See **change-protocol** skill for the full grammar

### 6. Detect domain impact

Run the domain-impact checklist (9 items, defined in the **change-protocol**
skill). Write the filled-in checklist into `design.md` under a "Domain Impact
Assessment" section. Then update `meta.yaml`:

- `domain_impact: none | additive | breaking`
- `domain_changes:` list (if any)

**If impact is `additive` or `breaking`:** the FIRST task in `tasks.md`
(below) must be `- [ ] 0.1 Update <domain_model> with: <domain_changes>`.

### 7. Create `tasks.md` (final artifact)

```markdown
# Tasks: <title>

## 0. Domain model (if impact ≠ none)

- [ ] 0.1 Update <domain_model> with: <domain_changes>

## 1. <Phase Name>

- [ ] 1.1 Task description
- [ ] 1.2 Task description

## 2. <Phase Name>

- [ ] 2.1 Task description
```

Tasks should be small and concrete — "implement X in file Y" is good;
"build the feature" is not.

### 8. Summarize

## Output

```
## Change Ready: <name>

**Type:** <type>
**Feature group:** <group or null>
**Domain Impact:** <impact>
**Location:** changes/<name>/

### Artifacts Created
- proposal.md (if applicable)
- specs/<capability>/spec.md (if applicable)
- design.md (if applicable)
- tasks.md — N tasks

### Domain Impact
<checklist results or "None detected">

Ready for implementation. Run `/sdlc:apply` to start, or `/sdlc:explore` to
think through open questions first.
```

## Guardrails

- Create ALL artifacts required for the type — don't skip any
- Always read architecture context BEFORE writing artifacts
- Always run the domain-impact checklist — this is the critical gate
- If context is critically unclear, ask the user — but prefer reasonable
  decisions to keep momentum (that's the whole point of `/sdlc:ff`)
- If a change with that name already exists, suggest `/sdlc:continue` instead
- Keep artifacts concise — proposals 1-2 pages, designs focused on decisions
