# Agentic SDLC

> **Looking for the narrative overview?** See
> [`site/content/writing/agentic-sdlc/index.md`](../../site/content/writing/agentic-sdlc/index.md)
> — it explains *why* the system exists, walks through a bootstrap → change → archive
> cycle end-to-end, and covers the rule-distillation loop and living-documentation
> model. This README is the contributor reference (file layout, current state,
> install, how to extend).

Opinionated commands and skills that codify how personal projects get built
and evolved:

- **Bootstrap** — Cloudflare as the infrastructure baseline, vanilla JS + Vite
  for SPAs, Hono for TS Workers, FastAPI (+ `sqlalchemy-cloudflare-d1`) for
  Python Workers, Scaleway for email, D1 for state, R2 for blobs, a Makefile
  as the project's single integration point.
- **Changes** — a typed-change protocol on top of OpenSpec with 8 change
  types, a 9-item domain-impact checklist, a rule-distillation loop, delta
  specs that merge into main specs on archive, and an acceptance-criteria
  gate.

One bootstrap per project, then **everything else is a change**.

Reference implementation: `~/code/blackwhite/kaminkommander` (infrastructure
patterns) and `~/code/blackwhite/.claude/skills/change-*` (change-management
patterns).

**Not installed by `make install`.** This is personal-machine-only tooling.
See [Install](#install). Don't install on a Paysafe / work machine.

---

## Commands

### Bootstrap (rare, one-shot)

- **`/sdlc:bootstrap <name>`** — new project from scratch. Picks runtime,
  creates monorepo, wires Cloudflare bindings, generates Makefile +
  `architecture/` + `.sdlc.yaml`, runs `openspec init`, creates Obsidian
  project note, initial commit.
- **`/sdlc:import <path>`** — retrofit an existing project. Adds Makefile,
  `architecture/`, `.dev/`, `.sdlc.yaml`, 1Password env sync; leaves stack
  as-is.

### Changes (everyday)

Ported from `~/code/blackwhite/.claude/skills/change-*` with generalization.
All 7 read the [`change-protocol`](skills/change-protocol/SKILL.md) skill for
templates, type matrix, domain-impact checklist, and rule-distillation format.

- **`/sdlc:new <name>`** — classify + scaffold a new change. One artifact at
  a time (shows first template, then STOPs).
- **`/sdlc:ff <name>`** — fast-forward: classify + ALL artifacts in one go,
  including domain-impact checklist and tasks.md. Ready to implement.
- **`/sdlc:continue`** — create the next missing artifact in sequence for an
  in-flight change.
- **`/sdlc:apply`** — implement tasks from a change; reads rules + guidelines
  before starting; prompts for rule-distillation when tasks are done.
- **`/sdlc:verify`** — four-dimensional verification report
  (completeness / correctness / AC gate / coherence). Run before archive.
- **`/sdlc:archive`** — distill rules, merge delta specs into main specs via
  intelligent ADDED/MODIFIED/REMOVED/RENAMED grammar, move to
  `archive/YYYY-MM-DD-<name>/`. Supports batch mode.
- **`/sdlc:explore`** — thinking partner. No application code written; may
  create change artifacts if asked. Reads architecture context, visualizes
  with ASCII diagrams.

---

## Layout

```
claude-code/sdlc/
├── README.md                    # this file
├── commands/                    # slash commands — explicit user triggers
│   ├── bootstrap.md             # /sdlc:bootstrap — new project from scratch
│   ├── import.md                # /sdlc:import    — retrofit existing project
│   ├── new.md                   # /sdlc:new       — new change (one artifact)
│   ├── ff.md                    # /sdlc:ff        — new change (all artifacts)
│   ├── continue.md              # /sdlc:continue  — next artifact
│   ├── apply.md                 # /sdlc:apply     — implement tasks
│   ├── verify.md                # /sdlc:verify    — verify before archive
│   ├── archive.md               # /sdlc:archive   — distill + sync + archive
│   └── explore.md               # /sdlc:explore   — thinking mode
└── skills/                      # capability skills — auto-triggered while working
    ├── change-protocol/         # shared knowledge base for all /sdlc:* change commands
    │   ├── SKILL.md             #   types, checklist, templates, delta-spec grammar
    │   └── scripts/
    │       └── verify-ac.py     #   AC gate — copied to tools/ during bootstrap
    ├── cloudflare-baseline/     # wrangler.jsonc, Workers/Pages/D1/R2, service bindings
    ├── local-dev/               # Makefile macros, .dev/logs, D1 snapshot/restore
    ├── secrets-1password/       # 1Password Documents API env sync
    ├── ddd-layout/              # bounded contexts, models/routes/schemas, architecture/
    ├── scaleway-email/          # separate email Worker + D1 + service binding pattern
    ├── python-worker/           # FastAPI + sqlalchemy-cloudflare-d1 + lazy lifespan
    ├── hono-worker/             # TS Workers with Hono (default for non-Python backends)
    └── cicd/                    # GitHub Actions (e2e + typecheck); deploys via make
```

---

## Install

```bash
make install-sdlc       # symlinks commands/ and skills/ into ~/.claude/
make uninstall-sdlc     # removes the symlinks
make doctor-sdlc        # reports install state
```

After install:

- `~/.claude/commands/sdlc/{bootstrap,import,new,ff,continue,apply,verify,archive,explore}.md`
  → `/sdlc:bootstrap`, `/sdlc:new`, etc.
- `~/.claude/skills/{change-protocol,cloudflare-baseline,...}/` — auto-triggered
  by Claude based on each skill's description

---

## The `.sdlc.yaml` config

`/sdlc:bootstrap` writes this to the project root; every `/sdlc:*` change
command reads it. See the
[`change-protocol` skill](skills/change-protocol/SKILL.md#10-sdlcyaml-config-reference)
for the full reference.

```yaml
feature_groups: []                       # empty = AC gate skipped (graceful degradation)
domain_model: architecture/domain-model.md
rules_file: architecture/rules.md
guidelines: architecture/guidelines.md
acceptance_dir: architecture/acceptance
decisions_dir: architecture/decisions
changes_dir: changes
specs_dir: openspec/specs
```

When `feature_groups` is empty, the AC gate in `/sdlc:verify` skips cleanly —
good for early-stage projects. Populate it when the project is big enough to
need formal AC tracking.

---

## Defaults (bootstrap)

| Concern            | Default                                                       |
|--------------------|---------------------------------------------------------------|
| Repo shape         | npm workspaces monorepo, uv for Python, Makefile as entrypoint |
| TS Workers         | Hono                                                          |
| Python Workers     | FastAPI + `sqlalchemy-cloudflare-d1` + lazy lifespan          |
| SPAs               | Vanilla JS + Vite (Pages)                                     |
| Heavy jobs         | Container via Durable Object pool                             |
| DB                 | D1 per service (satellites get their own)                     |
| Storage            | R2                                                            |
| Worker ↔ Worker    | Service bindings, never HTTP                                  |
| Email              | Dedicated Scaleway email Worker + TEST_MODE flag              |
| Secrets            | `.dev.vars` locally, `wrangler secret put` in prod, 1Password SoT |
| Local DB reset     | `make snapshot-db` / `make restore-db`                        |
| Docs               | `architecture/{domain-model,guidelines,rules,decisions/,acceptance/}.md` + OpenSpec |
| Observability      | Logs in `.dev/logs/`; add more when needed                    |

---

## Current state

| Artifact | Status | Notes |
|---|---|---|
| [commands/bootstrap.md](commands/bootstrap.md) | **fleshed** | 10-step orchestrator; delegates to capability skills |
| [commands/import.md](commands/import.md) | **fleshed** | 5-step retrofit flow (detect → classify → add missing → baseline ADR → summarize); per-stack skill routing; non-destructive |
| [commands/new.md](commands/new.md) | **fleshed** | Classify + first-artifact template; reads `.sdlc.yaml` for AC flow |
| [commands/ff.md](commands/ff.md) | **fleshed** | Classify + all artifacts + domain-impact checklist in one shot |
| [commands/continue.md](commands/continue.md) | **fleshed** | Next-artifact-in-sequence with domain-impact on design.md |
| [commands/apply.md](commands/apply.md) | **fleshed** | Task loop + distillation prompt |
| [commands/verify.md](commands/verify.md) | **fleshed** | 4-dimensional report, graceful degradation if `.sdlc.yaml` minimal |
| [commands/archive.md](commands/archive.md) | **fleshed** | DISTILL → delta-spec merge → archive; single + batch |
| [commands/explore.md](commands/explore.md) | **fleshed** | Stance + change-awareness; no code writes |
| [skills/change-protocol](skills/change-protocol/SKILL.md) | **fleshed** | 8 types, artifact matrix, 9-item checklist, meta.yaml schema, delta-spec grammar, rule format, ADR template, `.sdlc.yaml` ref |
| [skills/change-protocol/scripts/verify-ac.py](skills/change-protocol/scripts/verify-ac.py) | **fleshed** | AC gate with graceful degradation when `feature_groups: []` |
| [skills/local-dev](skills/local-dev/SKILL.md) | **fleshed** | Full Makefile macros, `.dev/` layout, D1 snapshot/restore, port numbering |
| [skills/cloudflare-baseline](skills/cloudflare-baseline/SKILL.md) | **fleshed** | 4 full `wrangler.jsonc` templates (TS/Python Workers, Pages SPA, Container gateway); D1/R2/service-binding/DO conventions; custom-domain routing; `make deploy` with `GIT_COMMIT`; `pywrangler` vs `wrangler` |
| [skills/secrets-1password](skills/secrets-1password/SKILL.md) | **fleshed** | Full `backup-env` / `restore-env` Makefile recipes, fresh-machine onboarding flow, `op` CLI prereqs, ENV_FILES convention, rotation order, pitfalls (title collisions, non-atomic restore, session expiry) |
| [skills/ddd-layout](skills/ddd-layout/SKILL.md) | **fleshed** | 1:1 models/routes/schemas convention + full `domain-model.md` / `guidelines.md` / `rules.md` / ADR templates; ADR-worthiness checklist |
| [skills/scaleway-email](skills/scaleway-email/SKILL.md) | **fleshed** | Full satellite wiring + 3 migrations (preference, template, settings); verbatim `scaleway.py` with dual send paths (CF fetch + httpx fallback); unsubscribe token flow; TEST_MODE as DB state |
| [skills/python-worker](skills/python-worker/SKILL.md) | **fleshed** | Full `pyproject.toml`, `src/worker.py`, `src/app.py` (lazy lifespan), `src/db.py`; models/routes/schemas templates; migration runner; pyodide gotchas |
| [skills/hono-worker](skills/hono-worker/SKILL.md) | **fleshed** | Full `package.json`, `tsconfig.json`, `vitest.config.ts`, `src/index.ts`, hand-maintained Env type, JWT middleware via Web Crypto, Zod Create/Update/Read/ListItem |
| [skills/cicd](skills/cicd/SKILL.md) | **fleshed** | Full `ci.yml` (typecheck + test jobs); `make typecheck` / `make test` recipes for mixed Node/Python; optional Playwright job (build+list, not full run); graduation signals |

Run `make doctor-sdlc` to verify symlinks on your current machine.

---

## Extending the system

### Filling out a stub skill

1. Open `skills/<name>/SKILL.md` and read the TODO list at the bottom.
2. For each TODO, work in this order — it avoids churn:
   1. **Show the artifact** — name a file path and what it is.
   2. **Embed a copy-pasteable template** — a real example, not prose description. Prefer fenced code blocks labelled with the target filename.
   3. **Annotate the non-obvious** — one-liner per subtlety (why this flag, what this compat date means). Everything obvious should be omitted.
   4. **Reference `~/code/blackwhite`** for a living example. When the skill contradicts kaminkommander, the skill is usually wrong.
3. End every skill with an "Out of scope — see sibling skills" handoff table.
4. Bump or delete the TODO list as you fill items — keep the list honest.

### Adding a new capability skill

```
mkdir claude-code/sdlc/skills/<new-name>
$EDITOR claude-code/sdlc/skills/<new-name>/SKILL.md
# (frontmatter: name, description — description is how Claude decides to trigger it)
make install-sdlc   # picks up the new dir automatically
```

Description-writing rule: be specific about *when* to use the skill, not what
it is. Triggers fire on description matching — "Use when scaffolding a new
Worker" is useful; "Cloudflare infrastructure" is not.

### Adding a new slash command

```
$EDITOR claude-code/sdlc/commands/<name>.md
# (frontmatter: name=sdlc:<name>, description)
make install-sdlc
```

Commands orchestrate — they call out to capability skills. Keep prose thin;
link to the skill that owns each step. A 200-line command that re-explains
what's already in a skill is a smell.

### Install flow — how it wires up

`make install-sdlc` creates two kinds of symlinks:

- Every file in `commands/*.md` → `~/.claude/commands/sdlc/<name>.md`. The
  subdirectory becomes the `sdlc:` prefix, so `new.md` → `/sdlc:new`.
- Every directory in `skills/<name>/` → `~/.claude/skills/<name>` (no prefix
  — these are the default on a personal machine).

Idempotent — safe to re-run after adding a new skill or command.

---

## Blackwhite-cleanup candidates (flagged during port, not acted on)

Noted while reading `~/code/blackwhite/.claude/skills/change-*` for the port.
None of these block anything here — they're opportunities to tidy kaminkommander
itself. Left as a list so they can be picked up in a blackwhite session if/when
you want to:

1. `changes/archive/2026-04-04-r2-image-storage/meta.yaml` has `null` /
   empty `domain_impact` / `domain_changes` / `rules_distilled` / `completed`
   despite being an archived change. Backfill or re-archive.
2. Most archived changes are missing the newer `feature_group` field in
   `meta.yaml` (the field was introduced after they were archived). Retroactive
   tagging would make the AC gate apply consistently to history.
3. `tools/verify-ac.py` hard-errors if `feature_group` is absent — inconsistent
   with the "graceful degradation" spirit. The ported version here already has
   the fix (skips if `feature_groups: []`).
4. `architecture/decisions/` has a `template.md` but no scaffold script. When
   `/change:archive` suggests creating an ADR, it's manual. Candidate:
   `scripts/create-adr.sh` to scaffold with timestamp + next ID.
5. No resync script for delta specs: changes completed before spec-sync was
   automated don't have their deltas merged into main specs. Candidate:
   `scripts/resync-archived-specs.py` to audit and offer to merge.
