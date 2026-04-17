---
name: ddd-layout
description: Lightweight Domain-Driven Design for personal SDLC projects — bounded contexts documented in architecture/domain-model.md, 1:1 models/routes/schemas folder convention per service, ADR policy with a template in decisions/, distilled rules in rules.md, coding conventions in guidelines.md, acceptance criteria in acceptance/<group>.md. Use whenever scaffolding architecture/, writing a domain-model entry, authoring an ADR, or deciding whether a change needs one.
---

# DDD layout

Lightweight DDD as practiced in `~/code/blackwhite/kaminkommander` — not
the full Evans/Vernon treatment, but the parts that pay off at small-team
scale. The full ADR / meta.yaml / delta-spec lifecycle lives in the
**change-protocol** skill; this one owns the files that sit in
`architecture/` and the per-service source-folder convention.

---

## Source-folder convention (per service)

```
apps/<svc>/src/
├── models/          # ORM / dataclasses, one file per aggregate
├── routes/          # HTTP handlers, 1:1 with models
├── schemas/         # Pydantic / Zod validators — Create/Update/Read/ListItem
├── domain/          # Pure domain logic, no I/O (optional — add only if it earns its keep)
└── infrastructure/  # DB, R2, external APIs (optional)
```

The **1:1 parallelism** between `models/`, `routes/`, and `schemas/` is
the load-bearing convention. It makes "where does X live?" trivial and
keeps PRs small. An entity called `resource` gets exactly three files:

- `src/models/resource.py` (or `.ts`)
- `src/routes/resource.py` (or `.ts`)
- `src/schemas/resource.py` (or `.ts`)

The `domain/` and `infrastructure/` folders are **optional**. Add them only
when the service has enough pure domain logic (calculations, state
machines) to justify the extra indirection. Most early-stage services
don't. Kaminkommander has 25 route files and no `domain/` folder — pure
logic lives as module-level functions in routes.

---

## `architecture/` folder — the repo root

`/sdlc:bootstrap` seeds this at project creation. Every personal project
has:

```
architecture/
├── domain-model.md          # bounded contexts, aggregates, invariants, glossary
├── guidelines.md            # coding/style/API conventions, opinionated
├── rules.md                 # distilled rules (R-NNN) — grows over time
├── decisions/
│   ├── template.md          # ADR template
│   └── NNNN-<slug>.md       # one file per ADR, sequentially numbered
└── acceptance/
    └── <group>.md           # AC files per feature group (if .sdlc.yaml has groups)
```

---

## `domain-model.md` — template

Lifted and generalized from `~/code/blackwhite/architecture/domain-model.md`.
Update the `Last reviewed` date whenever you re-read it and confirm it
matches reality.

```markdown
# Domain Model — <Project Name>

Living document. Updated whenever a change touches domain concepts.

Last reviewed: <YYYY-MM-DD>

## Bounded Contexts

### <Context Name> (primary)

<One-sentence description of what this context owns.>

**Aggregate: <Aggregate Name>**

<One-sentence description.>

| Concept | Type | Description |
|---------|------|-------------|
| <Name>  | Aggregate Root | <description> |
| <Name>  | Value Object (enum) | <description — list enum values inline> |
| <Name>  | Entity | <description> |
| <Name>  | Value Object | <description> |

### <Second Context>

<description>

(add more contexts as the project grows)

## Invariants

System-wide rules that must hold. Each one has a stable reference (R-NNN)
once distilled — see `rules.md`.

- **[I-001]** Every `<Entity>` is owned by exactly one `<ParentEntity>`.
- **[I-002]** `<Field>` transitions are strictly monotonic (OFFEN → GEPLANT → …).

## Glossary

Short definitions. Bilingual if the domain language differs from the code
language (see guidelines.md — kaminkommander uses German domain terms
with English code).

- **<Term>** — <definition>
```

---

## `guidelines.md` — template

Generalized from kaminkommander's guidelines. Tighten or drop sections
that don't apply.

```markdown
# Coding Guidelines — <Project Name>

## Language & Naming

- **Domain language:** <pick one — matches domain experts>. Code structure
  (imports, variables, function names) is English.
- **Files:** snake_case (`resource.py`, `resource_list.js`)
- **Classes/Schemas:** PascalCase (`ResourceCreate`, `ResourceRead`)
- **Enums:** UPPER_SNAKE_CASE (`ResourceStatus.ACTIVE`)
- **Routes:** kebab-case in URLs (`/api/resources/`)

## Schema Conventions (API)

Every domain entity follows this pattern:

| Schema | Purpose | Fields |
|--------|---------|--------|
| `<Entity>Create` | POST body | Required fields only |
| `<Entity>Update` | PATCH body | All optional (partial update) |
| `<Entity>Read` | GET response | All fields + timestamps + system fields |
| `<Entity>ListItem` | List response item | Subset + denormalized display fields |
| `<Entity>List` | Paginated wrapper | `items: list[ListItem]`, `total: int` |

## Database Conventions (D1/SQLite)

- **Primary keys:** TEXT (UUIDs), not INTEGER
- **Datetimes:** ISO 8601 TEXT — no SQLite TIMESTAMP type
- **Enums:** TEXT with CHECK constraints
- **Foreign keys:** Reference columns without `FOREIGN KEY` (D1 limitation) —
  enforce in application code
- **Denormalization:** Allowed for list endpoints to avoid joins
- **Migrations:** Sequential numbered files (`0001_*.sql`). Never modify a
  deployed migration — add a new one.

## API Design

- **REST with pragmatic shortcuts.** Standard CRUD. Custom actions as
  sub-resources (`POST /api/resources/{id}/publish`).
- **Pagination:** `?page=1&page_size=20` on list endpoints. Response
  includes `total`.
- **Filtering:** Query params on list endpoints. Exact match for IDs,
  partial match for text search.
- **Auth:** Service token (`X-Service-Token`) for satellite-to-satellite.
  JWT (`Authorization: Bearer`) for user requests.
- **Error responses:** Framework default exceptions with status + detail.

## Testing

- **Backend:** integration-style tests against the Worker with real D1
  (snapshot/restore pattern — see **local-dev** skill)
- **Frontend:** manual or Playwright e2e
- **Contract tests:** only for external-system integrations

## What NOT to do

- Don't enforce foreign keys in D1 migrations — not supported reliably
- Don't store computed display values in the database — compute in schemas
- Don't modify deployed migrations — always a new file
- Don't add features (or frameworks) speculatively — let the need surface first
```

---

## `rules.md` — the distilled-rules file

`/sdlc:bootstrap` writes this as an empty header. The rule-distillation
loop in `/sdlc:apply` and `/sdlc:archive` appends rules here over time.

```markdown
# Distilled Rules — <Project Name>

Rules extracted from past changes. Each rule has an ID, a source change,
and the context that produced it. Rules are permanent unless explicitly
superseded (mark as `SUPERSEDED by R-xxx`).

Rule format defined in the **change-protocol** skill.

---

## Domain Rules

<!-- R-001, R-002, ... appended by /sdlc:apply and /sdlc:archive -->

## Technical Rules

<!-- same here — separate section for non-domain rules -->
```

Group into "Domain Rules" and "Technical Rules" once there are enough to
warrant it — kaminkommander split them after ~5 rules accumulated.

---

## `decisions/template.md` — ADR template

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

(This template is identical to the one in the **change-protocol** skill —
it's duplicated here because it lives on disk in each project's
`architecture/decisions/template.md`.)

Numbering is sequential starting at 0001. `/sdlc:bootstrap` writes
`0001-baseline.md` recording the stack choices made during bootstrap.

---

## `acceptance/<group>.md` — per-group AC files

Only created for projects where `.sdlc.yaml` has a non-empty
`feature_groups` list. Each group gets a file; each AC inside is a
headed block matching the grammar `verify-ac.py` parses (see
**change-protocol** skill section 11).

```markdown
# Acceptance Criteria — <group>

Status legend: ✅ implemented and tested | ⚠️ implemented, tests partial |
📋 specified, not yet implemented

---

### AC-<GROUP>-01 · <short title> ✅

Given `<context>`
When `<action>`
Then `<expected>`

- Test: `apps/<svc>/tests/test_<something>.py::test_<case>`
```

The `verify-ac.py` gate enforces the status emoji, the `Test:` marker with
a backtick-quoted path, and that the test file exists on disk.

---

## When to write an ADR

ADRs anchor architectural choices. Write one for:

- **Introducing or removing a bounded context**
- **Changing an aggregate's identity or lifecycle** (e.g. switching UUIDs
  to natural keys)
- **Choosing between persistence options** (D1 vs. R2 vs. external)
- **Adopting a new external dependency that shapes the domain** (e.g.
  "Scaleway is our email provider"; "Stripe is our billing system")
- **Distilled rule is big enough** that future similar decisions should be
  anchored to it explicitly

**Do NOT** write an ADR for:

- Renaming a field, adding a column
- Changing an endpoint shape
- Choosing a linter, formatter, or dev-time convenience
- Anything that can be reverted in a PR without cross-context impact

When in doubt: can a future contributor work backwards from the rule
to "what decision produced this"? If yes and the rule matters, write the
ADR. If the rule is a minor convention, just add it to `rules.md` and move
on.

---

## Keeping `domain-model.md` honest

`/sdlc:new` and `/sdlc:ff` run the **domain-impact checklist** (see
**change-protocol** skill section 5) whenever a change touches domain
concepts. If impact is `additive` or `breaking`, the **first task** in
`tasks.md` is always "Update `architecture/domain-model.md` with
<domain_changes>".

This means `domain-model.md` is never behind the code for long — it's
updated before implementation, not after. Re-review the `Last reviewed`
date periodically and bump it when you've confirmed the model still
matches reality.

---

## Out of scope — see sibling skills

- **`change-protocol`** — 8 change types, meta.yaml schema, delta-spec
  grammar, rule-distillation prompt, ADR template duplication source,
  domain-impact checklist
- **`python-worker`** / **`hono-worker`** — apply the 1:1 convention in
  each runtime
- **`secrets-1password`** — where `.env.secrets.example` sits (not in
  `architecture/`, at the repo root)
