---
name: change-protocol
description: Shared change-management knowledge for personal SDLC projects — the 8 change types, artifact matrix per type, 9-item domain-impact checklist, meta.yaml schema, delta-spec grammar, rule-distillation prompt and format, ADR template, and .sdlc.yaml config reference. Auto-triggered when any /sdlc:new|ff|continue|apply|verify|archive|explore command runs.
---

# Change protocol

Every change to a personal SDLC-bootstrapped project follows this protocol.
It ensures changes are typed, domain impact is detected early, and learnings
are captured as rules.

The 7 `/sdlc:*` change commands all read this skill for their templates and
rules. Ported (with generalization) from
`~/code/blackwhite/architecture/change-protocol.md` +
`~/code/blackwhite/.claude/skills/change-*/SKILL.md`.

---

## 1. Change types

Every change has exactly one type. The type determines which artifacts are
required and what the review focus is.

| Type         | Tag           | Description                                      | Review focus                                          |
|--------------|---------------|--------------------------------------------------|-------------------------------------------------------|
| Feature      | `feature`     | New capability that didn't exist before          | Domain model impact, API surface, schema additions    |
| Enhancement  | `enhancement` | Improves an existing capability                  | Backward compatibility, migration path                |
| Bugfix       | `bugfix`      | Corrects incorrect behavior                      | Root-cause analysis, regression risk                  |
| UX           | `ux`          | UI/interaction improvement, no logic change      | Visual consistency, accessibility                     |
| Refactor     | `refactor`    | Restructures code without behavior change        | Equivalence proof, test coverage                      |
| Infra        | `infra`       | Build, deploy, CI, tooling, config               | Rollback plan, environment parity                     |
| Data         | `data`        | Migration, sync logic, data correction           | Idempotency, rollback, data integrity                 |
| Docs         | `docs`        | Documentation only                               | Accuracy, completeness                                |

---

## 2. Change lifecycle

```
1. CLASSIFY  →  2. SPEC  →  3. DETECT  →  4. IMPLEMENT  →  5. DISTILL  →  6. ARCHIVE
```

| Step      | Command                      | What happens                                               |
|-----------|------------------------------|------------------------------------------------------------|
| CLASSIFY  | `/sdlc:new` or `/sdlc:ff`    | Pick type, create `meta.yaml`, wire feature group + ACs    |
| SPEC      | `/sdlc:new` / `/sdlc:continue` / `/sdlc:ff` | Write proposal / design / specs / tasks artifacts    |
| DETECT    | same                         | Run the 9-item domain-impact checklist                    |
| IMPLEMENT | `/sdlc:apply`                | Work through `tasks.md`, mark each complete                |
| DISTILL   | end of `/sdlc:apply` or `/sdlc:archive` | Ask: did this reveal a rule? Append to `rules.md`    |
| ARCHIVE   | `/sdlc:archive`              | Sync delta specs → main specs, move to `archive/`          |

`/sdlc:verify` runs between IMPLEMENT and ARCHIVE to gate correctness.
`/sdlc:explore` is an orthogonal mode — no writes, just thinking.

---

## 3. Artifact matrix

| Type         | Required artifacts (in order)                          |
|--------------|--------------------------------------------------------|
| feature      | `proposal.md` → `specs/<cap>/spec.md` → `design.md` → `tasks.md` |
| enhancement  | `proposal.md` → `design.md` → `tasks.md`               |
| bugfix       | `design.md` (root cause) → `tasks.md`                  |
| ux           | `proposal.md` (before/after) → `tasks.md`              |
| refactor     | `design.md` (rationale) → `tasks.md`                   |
| infra        | `design.md` (rationale) → `tasks.md`                   |
| data         | `design.md` (migration + rollback) → `tasks.md`        |
| docs         | Direct edit — no artifacts                             |

---

## 4. `meta.yaml` schema

Every change directory has a `meta.yaml` at its root. This is the index that
makes change history searchable and links changes to the rules they produced.

```yaml
type: feature                           # one of the 8 types
title: Short description                # 5-10 words
trigger: What prompted this change      # issue, user feedback, tech debt, etc.
created: 2026-04-17                     # YYYY-MM-DD
feature_group: sync                     # from .sdlc.yaml; null if project has no groups
acceptance_criteria:                    # [AC-IDs] | [] | null
  - AC-SYNC-05                          #   [] = cross-cutting, explicitly no ACs
                                        #   null = project has no feature_groups yet
domain_impact: additive                 # none | additive | breaking | null (pre-DETECT)
domain_changes:
  - Description of what shifted in the domain model
rules_distilled:                        # R-NNN IDs added to rules.md as part of this change
  - R-012
completed: null                         # YYYY-MM-DD on archive; null while active
```

---

## 5. Domain-impact checklist

Run during SPEC (after `design.md` is drafted, before implementation). Write
the filled-in checklist into `design.md` under a "Domain Impact Assessment"
section, then update `meta.yaml`'s `domain_impact` and `domain_changes`
fields.

```markdown
## Domain Impact Assessment

- [ ] **New entity or aggregate?** → add to domain-model.md
- [ ] **New or changed enum values?** → update domain-model.md, check all consumers
- [ ] **New relationship between entities?** → update entity relationship diagram
- [ ] **Changed invariant?** → update invariants list, verify enforcement
- [ ] **New bounded context interaction?** → document the integration point
- [ ] **Schema change (Create/Update/Read)?** → verify schema-convention compliance
- [ ] **New migration?** → verify it's additive, document rollback path
- [ ] **Sync behavior change?** → verify external-system compatibility
- [ ] **Status workflow change?** → update status-transition documentation

### Impact: none | additive | breaking

### Domain model changes needed:
(describe or "none")
```

**Impact levels:**

- **`none`** — no domain-model doc update needed
- **`additive`** — new concepts added. Update `domain-model.md` BEFORE
  implementation. First task in `tasks.md` should be the doc update.
- **`breaking`** — existing concepts changed or removed. Requires
  `design.md` with migration rationale. Update `domain-model.md` BEFORE
  implementation. May trigger a new ADR.

---

## 6. Artifact templates

### `proposal.md` (feature, enhancement, ux)

```markdown
# Proposal: <title>

## Why
1-2 sentences on the problem or opportunity.

## What Changes
- Bullet list of changes. Be specific.
- Mark breaking changes with **BREAKING**.

## Capabilities
### New Capabilities
- `<kebab-case-name>` — description (each becomes a spec)

### Modified Capabilities
- `<existing-spec-name>` — what changes (check `<specs_dir>/` for names)

## Impact
Affected code, APIs, dependencies, or systems.
```

### `design.md` (bugfix, refactor, infra, data; also feature/enhancement)

```markdown
# Design: <title>

## Context
Background, current state, constraints.

## Root Cause (bugfix) | Rationale (refactor/infra) | Migration Plan (data)
Analysis of the problem or motivation.

## Decisions
Key technical choices with rationale.

## Risks / Trade-offs
[Risk] → Mitigation

## Rollback (data changes only)
Steps to reverse if needed.

## Domain Impact Assessment
<filled-in 9-item checklist from section 5>
```

### `tasks.md`

```markdown
# Tasks: <title>

## 0. Domain model (if impact ≠ none)

- [ ] 0.1 Update architecture/domain-model.md with: <domain_changes>

## 1. <Phase Name>

- [ ] 1.1 Task description (file path, expected change)
- [ ] 1.2 Task description

## 2. <Phase Name>

- [ ] 2.1 Task description
```

Tasks should be small and concrete. "Implement X in file Y" is a good task;
"build the feature" is not.

### `specs/<capability>/spec.md` (feature type only — delta format)

```markdown
# Spec Delta: <capability-name>

## ADDED Requirements

### Requirement: <requirement name>

<short description>

#### Scenario: <scenario name>

- **WHEN** <condition>
- **THEN** <expected behavior>

#### Scenario: <another scenario>

- **WHEN** ...
- **THEN** ...

### Requirement: <another>

...

## MODIFIED Requirements

### Requirement: <existing requirement name>

<what's different from the main spec>

## REMOVED Requirements

- `<requirement name>` — reason

## RENAMED Requirements

- `<old name>` → `<new name>`
```

---

## 7. Delta-spec grammar — merge semantics

`/sdlc:archive` merges `changes/<name>/specs/<cap>/spec.md` into the main
spec at `<specs_dir>/<cap>/spec.md`:

| Section in delta                  | Action on main spec                            |
|-----------------------------------|------------------------------------------------|
| `## ADDED Requirements`           | Append each requirement (create file if missing) |
| `## MODIFIED Requirements`        | Replace the matching requirement, preserving unchanged sub-sections |
| `## REMOVED Requirements`         | Delete the listed requirements                 |
| `## RENAMED Requirements`         | Rename in place; preserve content              |

**Batch-mode conflict resolution** (2+ changes touch the same capability):
apply in chronological order (older first), search the codebase for
implementation evidence when intent is ambiguous, note conflicts and
resolutions in the archive output.

---

## 8. Rule-distillation loop

The loop fires at two points:

1. **End of `/sdlc:apply`** — post-implementation, when all tasks are done
2. **Start of `/sdlc:archive`** — pre-archive, catches anything missed above

Both use this prompt:

> Did this change reveal anything worth capturing as a rule?
>
> - **Mistakes avoided**: what almost went wrong?
> - **Patterns discovered**: what approach worked well?
> - **Assumptions broken**: what did we learn about the domain?
> - **Debt identified**: what shortcut was taken deliberately?
>
> If nothing stands out, say 'none' and we'll proceed.

### Rule format (appended to `<rules_file>`, default `architecture/rules.md`)

```markdown
### R-NNN: <rule title>

**Source:** <change-name>
**Rule:** <the rule, one sentence>
**Why:** <the reason — what lesson produced it>
```

IDs are sequential starting from R-001. The "source" field anchors each rule
to the change that produced it so provenance is always traceable.

### Rules → ADRs

If a distilled rule is significant enough to affect future architectural
choices, `/sdlc:archive` offers to create an ADR. Use the template below.

---

## 9. ADR template

Location: `<decisions_dir>/NNNN-<slug>.md` (default
`architecture/decisions/NNNN-<slug>.md`). Numbered sequentially starting at
0001.

```markdown
# ADR-NNNN: Title

**Date:** YYYY-MM-DD
**Status:** proposed | accepted | superseded by ADR-NNNN
**Change:** reference to change name (if applicable)
**Type:** feature | enhancement | bugfix | ux | refactor | infra | data

## Context

What is the issue that we're seeing that is motivating this decision?

## Decision

What is the change that we're proposing and/or doing?

## Consequences

What becomes easier or more difficult to do because of this change?

## Domain Impact

Does this change the domain model? If yes, what was updated in
`domain-model.md`?

## Rules Produced

Did this decision produce any new rules? Reference them (e.g. R-011).
```

**When to write an ADR** (not for every change):
- Introducing or removing a bounded context
- Changing an aggregate's identity or lifecycle
- Choosing between persistence options (D1 vs. R2 vs. external)
- Adopting a new external dependency that shapes the domain
- A distilled rule is big enough that future similar decisions should be
  anchored to it

Not for: renaming a field, adding a column, changing an endpoint shape.

---

## 10. `.sdlc.yaml` config reference

Lives at the project root. Written by `/sdlc:bootstrap`. Read by every
`/sdlc:*` change command.

```yaml
# Feature groups — determines AC-gate behavior in /sdlc:verify.
# Empty list = project has not yet crystallized groups; AC gate skips
# gracefully. Populate when the project is big enough to need it.
feature_groups: []
# Example once populated:
# feature_groups:
#   - core
#   - email
#   - integrations

# Paths — defaults shown. Override only if your project deviates.
domain_model: architecture/domain-model.md
rules_file: architecture/rules.md
guidelines: architecture/guidelines.md
acceptance_dir: architecture/acceptance
decisions_dir: architecture/decisions
changes_dir: changes
specs_dir: openspec/specs
```

### AC gate behavior

- `feature_groups: []` → `/sdlc:new` skips the group + AC prompt; `meta.yaml`
  writes `feature_group: null` and `acceptance_criteria: null`;
  `/sdlc:verify`'s AC gate reports "skipped".
- `feature_groups` populated → `/sdlc:new` requires the user to pick a group
  and ACs; `/sdlc:verify` runs `scripts/verify-ac.py` and hard-fails if any
  referenced test is missing.
- `feature_group: cross-cutting` + `acceptance_criteria: []` → explicit
  opt-out for changes that don't belong to any single group. The verifier
  accepts this; the gate reports "skipped — cross-cutting".

---

## 11. Running `verify-ac.py`

The verify-ac script lives at `scripts/verify-ac.py` under this skill. During
`/sdlc:bootstrap`, it gets copied into the project's `tools/` directory (or
wherever the project's `.sdlc.yaml` says) so it runs against the project's
own `.sdlc.yaml`.

Usage (from the project root):

```bash
python tools/verify-ac.py changes/<name>
```

Exit codes:
- `0` — all referenced ACs exist, are ✅, cite a test path, and the test
  file exists on disk
- `1` — at least one AC check failed (details on stderr)
- `2` — usage error

The script reads the project's `.sdlc.yaml` to know `feature_groups` and
`acceptance_dir`. It does NOT execute tests — only validates the AC → test
wiring. `/sdlc:verify` reminds the user to run `make test` separately.

---

## 12. Project bootstrap checklist

When `/sdlc:bootstrap` runs, it seeds these files (see the `ddd-layout`
skill for the content templates):

- `architecture/domain-model.md` — empty skeleton, `last reviewed:` date
- `architecture/guidelines.md` — starter conventions
- `architecture/rules.md` — empty header, ready for first R-001
- `architecture/decisions/0001-baseline.md` — the bootstrap ADR
- `architecture/acceptance/` — empty directory
- `changes/` — empty directory (the `archive/` sibling is created on first
  archive, not up-front)
- `.sdlc.yaml` — with `feature_groups: []` and path defaults
- `tools/verify-ac.py` — copied from this skill's `scripts/` dir

After bootstrap, the first `/sdlc:new` creates the first `changes/<name>/`.
