---
name: secrets-1password
description: Secret management for personal SDLC projects using 1Password Documents API — local secrets live in gitignored env files; make backup-env uploads them as tagged Documents; make restore-env pulls them back on a fresh machine. Use when setting up a new project's secret layer, rotating a credential, wiring backup/restore into a Makefile, or onboarding a new machine.
---

# Secrets: 1Password Documents API

Hybrid env-file + 1Password workflow. Reference:
`~/code/blackwhite/Makefile` targets `backup-env` / `restore-env`.

## The model

- **Local dev** reads secrets from gitignored env files on disk (`.dev.vars`
  per Worker, `.env.secrets` at the repo root, etc.)
- **Source of truth** is the 1Password "Development" vault — env files are
  uploaded as Documents with deterministic tags
- **Production** is Cloudflare — `wrangler secret put <NAME>` ships prod
  secrets directly; 1Password does not mirror production values (write once
  to both, let 1Password be the recoverable local copy)

The win: you can delete every `.env.*` file in the repo fearlessly. One
command recovers them.

---

## Prerequisites

```bash
brew install --cask 1password 1password-cli
op signin                     # interactive sign-in on first use
```

Verify with `op whoami`. The account handle it returns is what subsequent
`op` calls use.

### Fresh-machine onboarding (the money shot)

```bash
git clone git@github.com:<you>/<project>
cd <project>
op signin                     # if not already
make restore-env              # pulls every env file from 1Password
make install                  # install deps
make dev                      # start the stack
```

Three commands to a running local stack. That's what the whole pattern is
for.

---

## Configuration

Put these at the top of the Makefile's `##@ Secrets` section:

```makefile
# ── 1Password Env Backup ────────────────────────────────────────
OP_VAULT  := Development          # dedicated vault — not "Private"
OP_PREFIX := <project>-env        # tag prefix — /sdlc:bootstrap fills in <project>

# All env files to back up (path:tag pairs — the tag becomes part of the
# Document title: <OP_PREFIX>-<tag>). Add a row per env file you want
# reversible.
ENV_FILES := \
	.env.secrets:env-secrets \
	apps/core/.dev.vars:core-dev-vars \
	apps/email/.dev.vars:email-dev-vars
```

When you add a new service that has its own `.dev.vars`, append a row here.
No other edits needed — `backup-env` and `restore-env` iterate over
`ENV_FILES` generically.

---

## Makefile recipes

### `backup-env`

```makefile
backup-env: ## Backup all env files to 1Password
	@printf "$(CYAN)Backing up env files to 1Password ($(OP_VAULT))...$(RESET)\n"
	@for pair in $(ENV_FILES); do \
		file=$${pair%%:*}; \
		tag=$${pair##*:}; \
		title="$(OP_PREFIX)-$$tag"; \
		if [ ! -r "$$file" ]; then \
			printf "  $(DIM)skip$(RESET)  $$file (not found)\n"; \
			continue; \
		fi; \
		tmp=$$(mktemp); \
		cat "$$file" > "$$tmp"; \
		if op document get "$$title" --vault $(OP_VAULT) > /dev/null 2>&1; then \
			op document edit "$$title" "$$tmp" --vault $(OP_VAULT) > /dev/null 2>&1; \
			printf "  $(GREEN)updated$(RESET)  $$file → $$title\n"; \
		else \
			op document create "$$tmp" --vault $(OP_VAULT) --title "$$title" > /dev/null 2>&1; \
			printf "  $(GREEN)created$(RESET)  $$file → $$title\n"; \
		fi; \
		rm -f "$$tmp"; \
	done
	@printf "$(GREEN)Backup complete.$(RESET)\n"
```

**Why the tmpfile:** `op document edit|create` wants a filename, not stdin.
Copying through a mktemp makes the behavior identical whether the source
file has unusual chars or symlinks.

**Why the `get`-before-`edit`:** `op document create` with a title that
already exists silently creates a *duplicate* Document. The `get` probe
distinguishes create-vs-update so the vault stays deduplicated.

**Skipped files (`not found`) are non-fatal.** A user may not have every
service set up locally; backup-env should succeed for what's present and
warn for what isn't.

### `restore-env`

```makefile
restore-env: ## Restore all env files from 1Password
	@printf "$(CYAN)Restoring env files from 1Password ($(OP_VAULT))...$(RESET)\n"
	@for pair in $(ENV_FILES); do \
		file=$${pair%%:*}; \
		tag=$${pair##*:}; \
		title="$(OP_PREFIX)-$$tag"; \
		dir=$$(dirname "$$file"); \
		mkdir -p "$$dir"; \
		if op document get "$$title" --vault $(OP_VAULT) --out-file "$$file" --force > /dev/null 2>&1; then \
			printf "  $(GREEN)restored$(RESET)  $$title → $$file\n"; \
		else \
			printf "  $(RED)missing$(RESET)   $$title (not in 1Password)\n"; \
		fi; \
	done
	@printf "$(GREEN)Restore complete.$(RESET)\n"
```

**Why `--force`:** `op document get --out-file` refuses to overwrite by
default. Restore is meant to be idempotent and authoritative — 1Password is
the source of truth, so overwriting is correct.

**Missing titles are non-fatal.** A project may declare an ENV_FILES row
for a service that hasn't had its first `backup-env` yet — print red and
move on, don't exit 1.

---

## Files and their roles

| File                            | Where                   | Committed? | Purpose                                              |
|---------------------------------|-------------------------|------------|------------------------------------------------------|
| `.env.secrets.example`          | repo root               | yes        | Manifest of env keys, empty values. Template for the real file. |
| `.env.secrets`                  | repo root               | no         | Master secret list for CLI tools + scripts           |
| `.dev.vars`                     | per Worker app          | no         | Wrangler-style local secrets (one per Worker)        |
| `.env.dev` / `.env.prod`        | per non-Worker tool     | no         | Node/Python scripts that need env at runtime         |
| 1Password "Development" vault   | —                       | —          | Source of truth; populated by `make backup-env`      |
| Cloudflare (`wrangler secret`)  | per Worker              | —          | Production — managed separately, not mirrored here   |

`.env.secrets.example` is the one file you DO commit. It lists every env
variable name with a blank value so a new contributor (or future-you on a
fresh machine) can see at a glance what secrets the project expects, before
running `make restore-env`.

---

## Rotation

When rotating a credential:

1. Generate the new value (Cloudflare, Scaleway, etc.)
2. Update the local file (`.dev.vars`, `.env.secrets`)
3. `wrangler secret put <NAME>` to update prod
4. `make backup-env` to push the new local value to 1Password

**Order matters:** update local first so `make backup-env` uploads the new
value. If you edit the 1Password Document directly and run `make restore-env`
later, you'll clobber whatever is currently local.

**Rule:** the env file is authoritative relative to 1Password. Never
hand-edit a Document in the 1Password UI.

---

## Pitfalls and edge cases

- **Title collisions across projects.** Two projects with the same
  `OP_PREFIX` value (e.g. both `my-env`) will overwrite each other's
  Documents. `/sdlc:bootstrap` defaults `OP_PREFIX` to the project name —
  don't override unless you know they're disjoint.
- **Vault choice.** The default `Private` vault is slow against the
  Documents API once it accumulates a few hundred items. A dedicated
  `Development` vault scoped to this use keeps things fast and easy to
  prune. Create it once via the 1Password UI or `op vault create Development`.
- **Non-atomic restore.** `make restore-env` iterates file-by-file. If it
  fails halfway, you have a mix of old and new secrets locally — re-run
  after fixing the underlying issue (usually sign-in expiry). There's no
  rollback; 1Password is the SoT.
- **Large secret files.** `op` has a 10MB Document size cap. Env files
  never approach this, but if you find yourself wanting to back up a
  service-account JSON or a private key, check the size first.
- **Session expiry.** `op` sessions expire (~30 min). If `backup-env` starts
  failing with "session expired", run `op signin` and retry. The recipes
  don't auto-retry on auth errors on purpose — silent retries after a
  password prompt is worse than a clear failure.
- **`op` not installed.** The recipes assume `op` is on the PATH. A
  `doctor` target (in a `##@ Health` section of the Makefile) can surface
  this with `command -v op >/dev/null || echo "op not installed"`.

---

## Out of scope — see sibling skills

- **`local-dev`** owns the Makefile structure, color palette, and the
  `##@ Secrets` section header this skill's targets live under
- **`cloudflare-baseline`** owns production secret management via
  `wrangler secret put` — 1Password does not sync production
- **`cicd`** owns CI secrets (GitHub Actions) — those go in repo secrets,
  not 1Password; CI doesn't need `op` access
