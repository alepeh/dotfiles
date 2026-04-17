---
name: sdlc:bootstrap
description: Bootstrap a new personal project on the agentic-SDLC baseline — Cloudflare-first infra, monorepo with Makefile, OpenSpec change management, .sdlc.yaml config, Obsidian project note, initial commit. Use when starting a greenfield repo outside work. After this, all subsequent work flows through /sdlc:new, /sdlc:ff, /sdlc:continue, /sdlc:apply, /sdlc:verify, /sdlc:archive, /sdlc:explore.
---

# /sdlc:bootstrap — Bootstrap a new project

Bootstrap a new personal project on the agentic-SDLC baseline. The reference
implementation these conventions are lifted from is `~/code/blackwhite/kaminkommander`
— when in doubt, open a file from there and mirror it.

**Scope gate:** This is for personal projects only. If the cwd is inside a
work / Paysafe repo, stop and ask the user to confirm before proceeding.

## Step 0 — Gather inputs

Ask the user (one AskUserQuestion call, all questions at once unless obvious):

1. **Project name** — used for directory, GitHub repo, Obsidian note. If they
   passed a name as the slash-command argument, use it and skip this.
2. **Runtime** — the *primary* app type:
   - `worker-ts` (default) — TS Workers with Hono
   - `worker-python` — FastAPI + `sqlalchemy-cloudflare-d1`
   - `pages-spa` — vanilla JS + Vite SPA on Pages (frontend-only)
   - `container` — Python service on a Cloudflare Container via Durable Object pool
3. **Needs D1?** (default yes) — creates a D1 with name `<project>-db`.
4. **Needs email?** (default no) — adds a satellite `email` Worker wired to Scaleway.
5. **Custom domain** — optional; e.g. `<name>.pehm.co.at`. Skip to use `*.workers.dev`.

Don't ask about TS vs vanilla JS for SPAs, test runners, linters, package manager
— those are fixed by the baseline.

## Step 1 — Create the repo on disk

Default parent directory: `~/code/`. Create `<parent>/<name>/` and `cd` into it.
If the directory already exists and is non-empty, stop and ask.

## Step 2 — Monorepo skeleton

Regardless of runtime, lay out the repo as a monorepo from day one (kaminkommander
proved this scales from one app to several without restructuring):

```
<name>/
├── Makefile                     # see Step 4 — single integration point
├── package.json                 # npm workspaces root: ["packages/*", "apps/*"]
├── .gitignore                   # .dev/, node_modules, .wrangler, .venv, .env*
├── .env.secrets.example         # secrets manifest (checked in, empty values)
├── .sdlc.yaml                   # see Step 5.5 — change-mgmt config
├── architecture/                # see Step 5
│   ├── domain-model.md
│   ├── guidelines.md
│   ├── change-protocol.md
│   ├── decisions/
│   │   └── 0001-baseline.md
│   ├── rules.md                 # seeded empty — distilled rules accumulate here
│   └── acceptance/              # per feature-group AC files (created as groups are defined)
├── changes/                     # active changes live here; archive/ sibling created on first archive
├── openspec/                    # created by `openspec init`
├── apps/
│   └── <primary>/               # runtime-specific scaffold, see Step 3
└── packages/
    └── shared/                  # auth, api-client, format, dom helpers
        └── package.json
```

Delegate the exact `wrangler.jsonc`, `pyproject.toml`, `src/` scaffolds to the
capability skills:

- **cloudflare-baseline** — wrangler.jsonc, bindings, routes, service bindings
- **hono-worker** — for `worker-ts` runtime
- **python-worker** — for `worker-python` runtime
- **ddd-layout** — `models/`, `routes/`, `schemas/`, domain-model.md
- **scaleway-email** — only if the user answered yes to email in Step 0

Read the SKILL.md of each before invoking — they document which files to write.

## Step 3 — Scaffold the primary app

Based on runtime answer:

- **worker-ts** → `apps/<name>/` with Hono, wrangler.jsonc, `src/index.ts`, Vitest.
  Hit the **hono-worker** skill.
- **worker-python** → `apps/<name>/` with `pyproject.toml` (uv), FastAPI,
  `src/{worker.py,app.py,db.py,models/,routes/,schemas/}`, `migrations/`.
  Hit the **python-worker** skill.
- **pages-spa** → `apps/<name>/` with Vite + vanilla JS + Playwright.
- **container** → `apps/<name>/` Python standalone + Dockerfile; plus a tiny
  `apps/<name>-gateway/` Worker that owns the Durable Object pool (see
  `~/code/blackwhite/kaminkommander-pdf/` as reference).

In all cases, create `.dev.vars` (gitignored) with commented-out placeholders
that match `.env.secrets.example`.

If the user said yes to D1 in Step 0, wire the binding as `DB` in wrangler.jsonc
and create `migrations/0001_init.sql` with a placeholder comment.

If the user said yes to email, scaffold `apps/email/` with its own D1 and a
service binding back to the primary app — use the **scaleway-email** skill.

## Step 4 — Makefile

Generate a root `Makefile` with kaminkommander's layout. Copy the
`start_service` / `stop_service` / `check_status` macros verbatim and adapt the
target list to the services you scaffolded. Standard sections:

```
##@ Services    dev, start, stop, status, logs
##@ Database    migrate, seed, snapshot-db, restore-db, reset-db
##@ Build       install, build, clean
##@ Test        test, test-e2e, typecheck, lint
##@ Deploy      deploy, deploy-<service>, release
##@ Secrets     backup-env, restore-env        (1Password Documents API)
```

Use the **local-dev** skill for the macros and `.dev/logs/` layout, and the
**secrets-1password** skill for `backup-env` / `restore-env`.

`.DEFAULT_GOAL := help` and a colored self-documenting `help` target — match the
style of this dotfiles repo's root Makefile.

## Step 5 — Architecture docs

Seed `architecture/`:

- **`domain-model.md`** — "last reviewed: <today>" + bounded-contexts table
  (with one placeholder context for the project's core concept) + invariants list
  (empty stubs) + glossary.
- **`guidelines.md`** — naming conventions, schema conventions, API shape,
  sync rules. Copy the structure from
  `~/code/blackwhite/architecture/guidelines.md` and generalize away project-specifics.
- **`rules.md`** — empty with a header. The rule-distillation loop
  (`/sdlc:apply` / `/sdlc:archive`) appends to this over time. Rules get
  sequential R-NNN IDs.
- **`decisions/0001-baseline.md`** — ADR recording the choices made in Step 0:
  runtime, D1/no-D1, email/no-email, custom domain. This pins the baseline so
  future drift is visible. Use the ADR template from the **change-protocol** skill.
- **`acceptance/`** — empty dir. Per feature-group AC files (`<group>.md`) get
  created as groups are introduced.

Use the **ddd-layout** skill for domain/guidelines templates and the
**change-protocol** skill for the ADR template + rules.md header.

## Step 5.5 — `.sdlc.yaml` config

Write a `.sdlc.yaml` at the repo root. This is what the `/sdlc:*` change
commands read to know project-specific knobs:

```yaml
# Feature groups. Starts empty — add them as the domain crystallizes.
# Each group gets an acceptance file at architecture/acceptance/<group>.md
# and AC IDs in the format AC-<GROUP>-NN (uppercased, hyphens kept).
feature_groups: []

# Paths — defaults shown; override if your project lays things out differently.
domain_model: architecture/domain-model.md
rules_file: architecture/rules.md
guidelines: architecture/guidelines.md
acceptance_dir: architecture/acceptance
decisions_dir: architecture/decisions
changes_dir: changes
specs_dir: openspec/specs
```

When `feature_groups` is `[]`, the AC-gate in `/sdlc:verify` degrades
gracefully: changes don't need `feature_group` / `acceptance_criteria` in
their `meta.yaml`. Add groups + populate the AC file when the project grows
enough to need the rigor.

## Step 6 — OpenSpec

```bash
openspec init
```

Run in the repo root. Don't overwrite `architecture/` — OpenSpec lives in
`openspec/` alongside it.

## Step 7 — CI

Add a single `.github/workflows/ci.yml` that runs `make typecheck` and
`make test` on pushes to main and all PRs. Use the **cicd** skill for the
template. No deploy workflow — deploys are manual via `make deploy`.

## Step 8 — GitHub repo + initial commit

Delegate to `/init-repo` if available (it already handles `gh repo create --private`
+ initial commit + push). Otherwise:

```bash
git init -b main
git add .
git commit -m "chore: bootstrap project via /sdlc:bootstrap"
gh repo create <name> --private --source=. --push
```

## Step 9 — Obsidian project note

Delegate to `/init-project` Step 5 (it already knows the Code Project Template
and the `notes/<Project Name>.md` path). Pass the GitHub URL from Step 8 so the
`repo:` frontmatter is populated.

## Step 10 — Summarize

Print:

- What was scaffolded (runtime, bindings, email yes/no)
- Next-steps checklist:
  1. `make install` — install app dependencies
  2. `wrangler login` if not already
  3. `make migrate` — run D1 migrations locally
  4. `make dev` — start the stack
  5. Fill in `architecture/domain-model.md` bounded contexts
  6. `/sdlc:new <first-change-name>` when ready for real work (or `/sdlc:explore` to think first)

Keep the summary to 10 lines or fewer.
