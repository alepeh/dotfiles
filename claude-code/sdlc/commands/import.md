---
name: sdlc:import
description: Retrofit an existing personal project onto the agentic-SDLC baseline — adds Makefile, architecture/, .dev/, 1Password env sync, OpenSpec. Leaves stack and source code untouched. Use when adopting the SDLC on a project that predates it.
---

# /sdlc:import — Retrofit an existing project

Brings a pre-existing repo onto the baseline **without rewriting the stack**.
Non-destructive: source code, build system, deployment remain unchanged. Only
adds the scaffolding that makes the other `/sdlc:*` commands work.

## Step 1 — Detect what's already there

Check in parallel for:

- `Makefile` or `Justfile`
- `architecture/` directory
- `openspec/` directory
- `.dev/` directory
- `package.json` workspaces configuration
- `wrangler.jsonc` / `wrangler.toml`
- Existing CI at `.github/workflows/`

Report a table of what exists vs. what's missing. Do not touch anything that
already exists without asking.

## Step 2 — Classify the stack

Read manifests to figure out: TS/JS, Python, monorepo shape, whether it's
already on Cloudflare. This determines which skills the retrofit pulls in:

- TS Worker on CF → **cloudflare-baseline**, **hono-worker**, **local-dev**
- Python on CF → **cloudflare-baseline**, **python-worker**, **local-dev**
- Non-CF stack → **local-dev** only; leave infra alone and flag it.

## Step 3 — Add missing scaffolding

For each missing piece, ask before adding. The additions, in order:

1. **`Makefile`** — using `local-dev` skill. If a Justfile exists, skip and
   note it; don't duplicate.
2. **`architecture/`** — using `ddd-layout` skill. Seed `domain-model.md` with
   bounded contexts extracted from the existing code structure (fold
   subdirectories of `src/` into contexts; flag ones that are ambiguous).
3. **`openspec init`** if `openspec/` is missing.
4. **`.env.secrets.example`** — scan existing `.env*` files, extract keys,
   blank the values, commit. Then use **secrets-1password** skill to wire
   `make backup-env` / `make restore-env`.
5. **`.github/workflows/ci.yml`** — minimal typecheck + test — only if no CI
   exists. Use the **cicd** skill.

## Step 4 — Capture a baseline ADR

Write `architecture/decisions/0001-baseline.md` documenting the stack *as it is
today* — runtime, DB, deployment mechanism, secrets location. This anchors
future changes so drift is visible.

## Step 5 — Summarize

Print: what was added, what was skipped (and why), what the user should verify
before the next `/sdlc:change`. Do not open a PR — let the user review the diff
and commit manually.
