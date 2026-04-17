---
name: ddd-layout
description: Domain-Driven Design layout for personal SDLC projects — bounded contexts, models/routes/schemas 1:1 parallelism, architecture/ folder with domain-model.md, guidelines.md, change-protocol.md, and ADRs. Use when designing domain structure, adding a new aggregate, or writing/editing architecture docs.
---

# DDD layout

Lightweight DDD as practiced in `~/code/blackwhite/kaminkommander` — not the
full Evans/Vernon treatment, but the parts that pay off at small-team scale.

## Folder convention (per service)

```
apps/<svc>/src/
├── models/          # ORM / dataclasses, one file per aggregate
├── routes/          # HTTP handlers, 1:1 with models
├── schemas/         # Pydantic / Zod validators — Create/Update/Read/ListItem
├── domain/          # Pure domain logic, no I/O (optional; use only if it earns its keep)
└── infrastructure/  # DB, R2, external APIs (optional)
```

The 1:1 `models/routes/schemas` parallelism is the load-bearing convention.
It makes "where does X live?" trivial and keeps PRs small.

## `architecture/` folder

Every project has this at the repo root:

- **`domain-model.md`** — THE source of truth for bounded contexts, aggregates,
  invariants, and glossary. Starts with `last reviewed: YYYY-MM-DD`. Update the
  date whenever you re-read and confirm it.
- **`guidelines.md`** — naming (prefer domain language even if non-English),
  schema conventions, API shape, sync rules. Short, opinionated.
- **`change-protocol.md`** — one-pager on change types, when an ADR is required,
  how domain impact is detected, rule-distillation loop.
- **`decisions/NNNN-<slug>.md`** — ADRs. Sequentially numbered. Each ADR has
  Context / Decision / Consequences / Status.

## When to write an ADR

- Introducing or removing a bounded context
- Changing an aggregate's identity or lifecycle
- Choosing between persistence options (D1 vs R2 vs external)
- Adopting a new external dependency that shapes the domain (e.g. Scaleway email)

Not for: renaming a field, adding a column, changing an endpoint shape.

## TODO

- [ ] Embed a `domain-model.md` template (headers, sections, example row)
- [ ] Embed a `guidelines.md` template generalized from kaminkommander
- [ ] Embed an ADR template (Context / Decision / Consequences / Status)
- [ ] Checklist for "does this change need an ADR?"
