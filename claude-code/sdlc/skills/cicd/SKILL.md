---
name: cicd
description: CI/CD conventions for personal SDLC projects — a single minimal GitHub Actions workflow that runs typecheck + test on push and PR; deploys are manual via `make deploy`, not automated; Playwright e2e runs only against Vite builds in CI, not the full Worker stack. Use when adding CI to a new project, wiring make typecheck for mixed Node/Python, debugging a failing workflow, or deciding whether to graduate to deploy automation.
---

# CI/CD

Deliberately minimal. Reference: `~/code/blackwhite/.github/workflows/e2e.yml`.

---

## Philosophy

- CI verifies **correctness**, not deployment
- Deploys are **manual** via `make deploy` — no GitHub Actions deploy
  workflow
- This is acceptable because these are solo / small-team projects; the cost
  of a bad deploy is low (rollback via `wrangler rollback` is a one-liner),
  and the cost of maintaining a deploy pipeline over project lifetimes is
  high
- **Graduate to automated deploys** when: team size > 1, or prod SLO
  matters enough that manual deploy anxiety becomes a bottleneck

---

## The one workflow: `.github/workflows/ci.yml`

`/sdlc:bootstrap` writes this. Generalized from
`~/code/blackwhite/.github/workflows/e2e.yml` — same shape, tighter scope
(typecheck + test by default; Playwright as an optional job).

```yaml
name: ci

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  typecheck:
    name: Typecheck
    runs-on: ubuntu-latest
    timeout-minutes: 5

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Set up Python (if project has any Python)
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - name: Install uv (if Python is present)
        run: pip install uv

      - name: Install workspace dependencies
        run: npm ci

      - name: Install Python dependencies
        run: |
          for dir in apps/*/; do
            if [ -f "$dir/pyproject.toml" ]; then
              (cd "$dir" && uv sync)
            fi
          done

      - name: Typecheck
        run: make typecheck

  test:
    name: Test
    runs-on: ubuntu-latest
    timeout-minutes: 10
    needs: typecheck

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'

      - run: pip install uv
      - run: npm ci
      - run: |
          for dir in apps/*/; do
            if [ -f "$dir/pyproject.toml" ]; then
              (cd "$dir" && uv sync)
            fi
          done

      - name: Test
        run: make test
```

Drop the Python steps if the project is TS-only. Drop the Node steps if
it's pure Python (rare — monorepo root is always npm workspaces).

---

## `make typecheck` recipe

Mixed Node/Python projects need one target that invokes both. Add to the
root Makefile in the `##@ Test` section:

```makefile
typecheck: ## Run typecheck across all apps (TS + Python)
	@printf "$(CYAN)Typechecking TS...$(RESET)\n"
	@for dir in apps/*/; do \
		if [ -f "$$dir/tsconfig.json" ]; then \
			(cd "$$dir" && npx tsc --noEmit) || exit 1; \
		fi; \
	done
	@printf "$(CYAN)Typechecking Python...$(RESET)\n"
	@for dir in apps/*/; do \
		if [ -f "$$dir/pyproject.toml" ]; then \
			(cd "$$dir" && uv run --with pyright pyright) || exit 1; \
		fi; \
	done
	@printf "$(GREEN)Typecheck passed.$(RESET)\n"
```

For TS, `tsc --noEmit` against each app's `tsconfig.json`.
For Python, Pyright via uv's ephemeral tool (no need to add pyright to
`pyproject.toml` dev deps).

---

## `make test` recipe

```makefile
test: ## Run all tests (Vitest + pytest)
	@printf "$(CYAN)Running Vitest...$(RESET)\n"
	@for dir in apps/*/; do \
		if [ -f "$$dir/vitest.config.ts" ]; then \
			(cd "$$dir" && npx vitest run) || exit 1; \
		fi; \
	done
	@printf "$(CYAN)Running pytest...$(RESET)\n"
	@for dir in apps/*/; do \
		if [ -f "$$dir/pyproject.toml" ]; then \
			(cd "$$dir" && uv run pytest) || exit 1; \
		fi; \
	done
	@printf "$(GREEN)All tests passed.$(RESET)\n"
```

---

## Playwright (optional)

Add **only** if the project has an SPA with a real user flow. For
single-Worker API-only projects, skip.

```yaml
  e2e:
    name: E2E (Playwright)
    runs-on: ubuntu-latest
    timeout-minutes: 20
    needs: test

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Install Playwright browsers
        working-directory: apps/<spa>
        run: npx playwright install --with-deps chromium

      # Starting the full Worker stack in CI is too slow and flaky.
      # We build the SPA and list Playwright tests to catch syntactic
      # regressions. Full e2e runs locally before merging.
      - name: Build SPA (sanity)
        working-directory: apps/<spa>
        run: npm run build

      - name: Lint Playwright tests (no run)
        working-directory: apps/<spa>
        run: npx playwright test --list

      - name: Upload Playwright report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: apps/<spa>/playwright-report/
          retention-days: 7
          if-no-files-found: ignore
```

**Why not run full Playwright in CI?** Spinning up miniflare + Vite dev
server + seeded D1 is slow and flaky. For personal projects, "build +
lint tests" in CI + "full run locally before merging" is the right
trade-off. Kaminkommander does the same — see the TODO comment in
`~/code/blackwhite/.github/workflows/e2e.yml`.

If you genuinely need full e2e in CI (e.g. a UI change that only broke in
prod-like conditions), run it on release branches only, not every PR.

---

## Required secrets

For CI as specified here: **none**. No deploys means no Cloudflare /
Scaleway credentials needed in GitHub. If a test hits an external
service, stub it — don't leak credentials into CI.

When you graduate to automated deploys, the required secrets become:

- `CLOUDFLARE_API_TOKEN` — scoped to the account + workers/pages deploy
- `CLOUDFLARE_ACCOUNT_ID`
- `SCALEWAY_*` — only if CI needs to send test emails (it shouldn't)

Add these to **repo secrets**, not environment secrets, until you have
separate prod/staging environments.

---

## Release

`make release` (from the root Makefile) bumps the version, tags, and
deploys. Run it manually from a clean working tree:

```makefile
release: ## Bump patch version, tag, and deploy
	@current=$$(grep '^version' apps/core/pyproject.toml | sed 's/.*"\(.*\)"/\1/'); \
	major=$$(echo $$current | cut -d. -f1); \
	minor=$$(echo $$current | cut -d. -f2); \
	patch=$$(echo $$current | cut -d. -f3); \
	next="$$major.$$minor.$$((patch + 1))"; \
	printf "$(CYAN)Bumping version: $$current → $$next$(RESET)\n"; \
	sed -i '' "s/^version = \"$$current\"/version = \"$$next\"/" apps/core/pyproject.toml; \
	sed -i '' "s/__version__ = \"$$current\"/__version__ = \"$$next\"/" apps/core/src/version.py; \
	git add apps/core/pyproject.toml apps/core/src/version.py; \
	git commit -m "chore(core): bump version to $$next"; \
	git tag "v$$next"; \
	printf "$(GREEN)Version bumped to $$next and tagged.$(RESET)\n"
	@$(MAKE) --no-print-directory deploy-core
```

Lifted verbatim from kaminkommander, parameterize the paths for your
project. Release cadence is ad-hoc, not scheduled.

---

## When to graduate to automated deploys

Signals it's time:

- Team > 1 contributor
- You're deploying multiple times a week
- You've had a "forgot to run make deploy" incident
- SLO matters enough that deploy anxiety is slowing you down
- You want staging + prod environments gated by branch

What changes when you graduate:

1. Add `deploy` jobs to `ci.yml` gated on `push` to `main`
2. Store `CLOUDFLARE_API_TOKEN` as a repo secret
3. Drop the manual `make deploy` / `make release` — GH Actions owns deploy
4. Add rollback workflow (`gh workflow run rollback.yml --field sha=<old>`)
5. ADR-worthy: this is an architectural change (see **ddd-layout** skill's
   "When to write an ADR")

Don't graduate preemptively. The manual-deploy pattern works for a long
time.

---

## Out of scope — see sibling skills

- **`cloudflare-baseline`** — `make deploy-<svc>` recipe, `GIT_COMMIT`
  var injection, Pages vs Worker deploy differences
- **`local-dev`** — `make test` / `make typecheck` are in the `##@ Test`
  section the local-dev skill owns
- **`hono-worker`** — Vitest config for Worker-native TS tests
- **`python-worker`** — pytest config + `httpx` integration-test pattern
