---
name: cicd
description: CI/CD conventions for personal SDLC projects — a single minimal GitHub Actions workflow that runs typecheck + test on push and PR; deploys are manual via make deploy, not automated. Use when adding CI to a new project or debugging a failing workflow.
---

# CI/CD

Deliberately minimal. Reference: `~/code/blackwhite/.github/workflows/e2e.yml`.

## Philosophy

- CI verifies **correctness**, not deployment
- Deploys are **manual** via `make deploy` — no GitHub Actions deploy workflow
- This is acceptable because these are solo / small-team projects; the cost of
  a bad deploy is low and the cost of maintaining deploy pipelines is high

## The one workflow: `.github/workflows/ci.yml`

Triggers: `push` to `main`, `pull_request` to `main`.

Jobs:

1. **setup** — checkout, cache deps, install (pnpm for Node, uv for Python)
2. **typecheck** — `make typecheck` (pnpm `tsc --noEmit` and/or `pyright`)
3. **test** — `make test` (Vitest for Node; pytest for Python)
4. **e2e** (optional) — only for projects with a Playwright suite; runs against
   a Vite build, not the full Worker stack (starting the full stack in CI is too slow)

Do NOT:
- Run `wrangler dev` or `pywrangler dev` in CI — miniflare bootstrap is slow
  and flaky. Mock bindings or test against the unit-test level.
- Gate merges on deploy success. Deploy after merge, not during.

## Required secrets

For CI: none. No deploys means no Cloudflare / Scaleway credentials needed in
GitHub. If a test hits an external service, stub it.

## Release

`make release` bumps the version in `src/version.py` (or the Node equivalent),
tags the commit, and deploys. Release cadence is ad-hoc, not scheduled.

## TODO

- [ ] Full `ci.yml` template (Node + Python matrix, cache strategy)
- [ ] `make typecheck` recipe for mixed Node/Python repos
- [ ] Playwright job template — when to enable, how to wire
- [ ] Document when to graduate to a real deploy pipeline (hint: team > 1)
