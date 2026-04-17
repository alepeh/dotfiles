---
name: local-dev
description: Local development conventions for personal SDLC projects — Makefile as the single entrypoint, start_service/stop_service/check_status macros for robust multi-process lifecycle, .dev/ runtime directory for PIDs and logs, D1 snapshot/restore for sub-second test reset. Use when writing or extending a project's Makefile, adding a new service to the local stack, or debugging local dev orchestration.
---

# Local development

Makefile-driven, process-based local orchestration. No docker-compose for
Cloudflare Workers — miniflare and `wrangler dev` / `pywrangler dev` already
do that job. Reference: `~/code/blackwhite/Makefile`.

## When to use this skill

- Scaffolding a Makefile during `/sdlc:new`
- Adding a new service (a second Worker, a new SPA, a container) to an existing project
- `/sdlc:import` adding a Makefile to a project that didn't have one
- Debugging "service won't stop" / "port still in use" issues

---

## 1. Runtime directory — `.dev/`

Every project has a `.dev/` directory at the repo root, created on demand by
the Makefile:

```
.dev/
├── pids/               # <svc>.pid files — tracked so stop_service can kill reliably
├── logs/               # <svc>.log files — one per service, overwritten on each start
└── snapshots/          # D1 snapshots for restore-db (one subdir per database)
```

Add to `.gitignore`:

```
.dev/
```

---

## 2. Service variable block

At the top of the Makefile, declare every service with a consistent 4-tuple:
**directory, port, start command**. This is the only place you edit when adding
a service.

```makefile
SHELL := /bin/bash

# ── Services ─────────────────────────────────────────────────────
CORE_DIR   := apps/core
CORE_PORT  := 8787
CORE_CMD   := uv run pywrangler dev        # Python Worker

EMAIL_DIR  := apps/email
EMAIL_PORT := 8788
EMAIL_CMD  := uv run pywrangler dev

APP_DIR    := apps/app
APP_PORT   := 5174
APP_CMD    := npx vite                     # Vite SPA

PDF_DIR    := apps/pdf/container
PDF_PORT   := 8080
PDF_CMD    := LOCAL_MODE=True .venv/bin/python main.py   # standalone Python

# ── Runtime dirs ─────────────────────────────────────────────────
DEV_DIR := .dev
PID_DIR := $(DEV_DIR)/pids
LOG_DIR := $(DEV_DIR)/logs
```

**Convention:** `<NAME>_DIR` / `<NAME>_PORT` / `<NAME>_CMD`. No exceptions — the
macros assume these names.

---

## 3. Color palette

Standard across every project so output looks the same everywhere:

```makefile
# ── Colors ───────────────────────────────────────────────────────
GREEN := \033[32m
RED   := \033[31m
CYAN  := \033[36m
DIM   := \033[2m
RESET := \033[0m
BOLD  := \033[1m
```

Use `printf` (not `echo -e`) for portability. Use `@printf` inside recipes.

---

## 4. The three macros — copy verbatim

These are the load-bearing abstraction. They are robust against:
- Stale PID files from a crashed previous run
- Processes that exit but leave children holding the port
- Ports held by something outside our PID tracking (e.g. a stray `vite` from another terminal)

### `stop_service`

```makefile
# $(call stop_service,name,port)
define stop_service
	@pid_file="$(PID_DIR)/$(1).pid"; \
	port="$(2)"; \
	if [ -f "$$pid_file" ]; then \
		pid=$$(cat "$$pid_file"); \
		if kill -0 "$$pid" 2>/dev/null; then \
			kill "$$pid" 2>/dev/null || true; \
			for i in 1 2 3 4; do \
				kill -0 "$$pid" 2>/dev/null || break; \
				sleep 0.5; \
			done; \
			if kill -0 "$$pid" 2>/dev/null; then \
				kill -9 "$$pid" 2>/dev/null || true; \
			fi; \
		fi; \
		rm -f "$$pid_file"; \
	fi; \
	port_pid=$$(lsof -ti :$$port 2>/dev/null || true); \
	if [ -n "$$port_pid" ]; then \
		kill $$port_pid 2>/dev/null || true; \
		sleep 0.5; \
		remaining=$$(lsof -ti :$$port 2>/dev/null || true); \
		if [ -n "$$remaining" ]; then \
			kill -9 $$remaining 2>/dev/null || true; \
		fi; \
	fi
endef
```

Sends SIGTERM, waits up to 2s, then SIGKILL. Also kills whatever is holding the
port (defense-in-depth against orphans from prior sessions).

### `start_service`

```makefile
# $(call start_service,name,dir,port,cmd)
define start_service
	@mkdir -p $(PID_DIR) $(LOG_DIR)
	$(call stop_service,$(1),$(3))
	@log_file="$(LOG_DIR)/$(1).log"; \
	pid_file="$(PID_DIR)/$(1).pid"; \
	port="$(3)"; \
	printf "$(CYAN)Starting $(1)$(RESET) (port $$port)..."; \
	cd "$(2)" && $(4) > "$(CURDIR)/$$log_file" 2>&1 & \
	echo $$! > "$$pid_file"; \
	pid=$$(cat "$$pid_file"); \
	for i in $$(seq 1 10); do \
		sleep 0.5; \
		if ! kill -0 "$$pid" 2>/dev/null; then \
			printf " $(RED)failed$(RESET)\n"; \
			echo "  Last log lines:"; \
			tail -5 "$(CURDIR)/$$log_file" 2>/dev/null | sed 's/^/  /'; \
			rm -f "$$pid_file"; \
			exit 1; \
		fi; \
		if lsof -ti :$$port >/dev/null 2>&1; then \
			printf " $(GREEN)ready$(RESET)\n"; \
			exit 0; \
		fi; \
	done; \
	printf " $(GREEN)started$(RESET) $(DIM)(port not yet open — check logs)$(RESET)\n"
endef
```

Key properties:
- Always stops first (idempotent — you can re-run `make dev` safely)
- Logs go to `.dev/logs/<svc>.log` so `make logs` works
- Polls the port for up to 5s; if the process dies, prints the last 5 log lines inline (saves a trip to the log file)
- If the process is alive but the port hasn't opened yet (common for slower Python imports), reports "started" anyway with a hint

### `check_status`

```makefile
# $(call check_status,name,port)
define check_status
	@pid_file="$(PID_DIR)/$(1).pid"; \
	port="$(2)"; \
	if [ -f "$$pid_file" ] && kill -0 $$(cat "$$pid_file") 2>/dev/null; then \
		printf "  $(GREEN)●$(RESET)  %-12s $(DIM)port %s$(RESET)\n" "$(1)" "$$port"; \
	elif lsof -ti :$$port >/dev/null 2>&1; then \
		printf "  $(GREEN)●$(RESET)  %-12s $(DIM)port %s (external)$(RESET)\n" "$(1)" "$$port"; \
	else \
		printf "  $(RED)●$(RESET)  %-12s $(DIM)port %s$(RESET)\n" "$(1)" "$$port"; \
	fi
endef
```

Three states:
- **green ●** — our PID is alive
- **green ● (external)** — port is held but not by us (something else grabbed it — investigate)
- **red ●** — not running

---

## 5. Standard targets

### `help` (default)

```makefile
.DEFAULT_GOAL := help

help: ## Show available targets
	@printf "$(BOLD)<ProjectName>$(RESET) — Local Development\n\n"
	@printf "$(BOLD)Usage:$(RESET) make [target]\n\n"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(CYAN)%-18s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@printf "$(DIM)  Individual: start-core, stop-core, start-app, stop-app, ...$(RESET)\n"
	@printf "$(DIM)  Database:   seed, reset-db, snapshot-db, restore-db$(RESET)\n"
```

Individual service targets are intentionally hidden from `make help` (too
noisy) — document them in the footer.

### `dev` / `start` / `stop` / `status`

```makefile
dev: start-core start-app ## Start the primary dev stack (core + app)
	@echo ""
	@printf "  $(BOLD)Core$(RESET)    http://localhost:$(CORE_PORT)\n"
	@printf "  $(BOLD)App$(RESET)     http://localhost:$(APP_PORT)\n"
	@echo ""

start: start-core start-email start-app ## Start all services
	@echo ""
	@printf "  $(BOLD)Core$(RESET)    http://localhost:$(CORE_PORT)\n"
	@printf "  $(BOLD)Email$(RESET)   http://localhost:$(EMAIL_PORT)\n"
	@printf "  $(BOLD)App$(RESET)     http://localhost:$(APP_PORT)\n"

stop: ## Stop all services
	$(call stop_service,core,$(CORE_PORT))
	$(call stop_service,email,$(EMAIL_PORT))
	$(call stop_service,app,$(APP_PORT))
	@printf "$(GREEN)All services stopped.$(RESET)\n"

status: ## Show service status
	@echo ""
	@printf "$(BOLD)Services:$(RESET)\n"
	$(call check_status,core,$(CORE_PORT))
	$(call check_status,email,$(EMAIL_PORT))
	$(call check_status,app,$(APP_PORT))
	@echo ""
```

**Difference between `dev` and `start`:** `dev` is the default workflow
subset (usually the minimum needed to work on the main app); `start` brings
everything up. Projects with only one app can collapse them.

### Individual service targets

```makefile
start-core:
	$(call start_service,core,$(CORE_DIR),$(CORE_PORT),$(CORE_CMD))

start-email:
	$(call start_service,email,$(EMAIL_DIR),$(EMAIL_PORT),$(EMAIL_CMD))

start-app:
	$(call start_service,app,$(APP_DIR),$(APP_PORT),$(APP_CMD))

stop-core:
	$(call stop_service,core,$(CORE_PORT))
	@printf "$(DIM)core stopped.$(RESET)\n"

stop-email:
	$(call stop_service,email,$(EMAIL_PORT))
	@printf "$(DIM)email stopped.$(RESET)\n"

stop-app:
	$(call stop_service,app,$(APP_PORT))
	@printf "$(DIM)app stopped.$(RESET)\n"
```

Don't add these to `.PHONY` one by one — do a single `.PHONY` line at the top
covering all targets.

### `logs`

```makefile
logs: ## Tail all service logs
	@tail -f $(LOG_DIR)/*.log 2>/dev/null || echo "No logs yet. Start services first."
```

For multi-service log muxing with colored prefixes, use [multitail](https://www.vanheusden.com/multitail/)
(add as a `make logs-pretty` variant if you want it — don't replace `logs`).

### `install` / `build` / `test` / `clean`

```makefile
install: ## Install all dependencies
	@printf "$(CYAN)Installing JS dependencies (workspaces)...$(RESET)\n"
	@npm install
	@printf "$(CYAN)Installing Python dependencies...$(RESET)\n"
	@for d in $(CORE_DIR) $(EMAIL_DIR); do \
		[ -f "$$d/pyproject.toml" ] && (cd "$$d" && uv sync); \
	done
	@printf "$(GREEN)All dependencies installed.$(RESET)\n"

build: ## Build all SPAs for production
	@printf "$(CYAN)Building app...$(RESET)\n"
	@npx vite build $(APP_DIR)
	@printf "$(GREEN)Build complete.$(RESET)\n"

test: ## Run all tests
	@cd $(CORE_DIR) && uv run pytest

clean: ## Stop all + remove runtime files and dist
	@$(MAKE) --no-print-directory stop
	@rm -rf $(DEV_DIR) $(APP_DIR)/dist
	@printf "$(GREEN)Cleaned.$(RESET)\n"
```

---

## 6. D1 snapshot / restore

Fast reset for test runs and "I messed up my local data" moments. Completes in
< 1 second regardless of DB size.

```makefile
# ── Local DB Management ──────────────────────────────────────────
# D1 SQLite paths (miniflare stores them here)
CORE_D1_DIR  := $(CORE_DIR)/.wrangler/state/v3/d1/miniflare-D1DatabaseObject
EMAIL_D1_DIR := $(EMAIL_DIR)/.wrangler/state/v3/d1/miniflare-D1DatabaseObject
SNAPSHOT_DIR := $(DEV_DIR)/snapshots

migrate: ## Apply D1 migrations (local)
	@cd $(CORE_DIR)  && uv run pywrangler d1 migrations apply <project>-core-db  --local
	@cd $(EMAIL_DIR) && uv run pywrangler d1 migrations apply <project>-email-db --local

reset-db: ## Wipe local D1, re-migrate, and seed
	@printf "$(CYAN)Wiping local D1 databases...$(RESET)\n"
	@rm -rf $(CORE_D1_DIR) $(EMAIL_D1_DIR)
	@printf "$(CYAN)Applying migrations...$(RESET)\n"
	@$(MAKE) --no-print-directory migrate
	@$(MAKE) --no-print-directory seed
	@printf "$(GREEN)Local DB reset complete.$(RESET)\n"

snapshot-db: ## Save local D1 state for fast restore
	@mkdir -p $(SNAPSHOT_DIR)
	@printf "$(CYAN)Snapshotting D1 databases...$(RESET)\n"
	@cp -r $(CORE_D1_DIR)  $(SNAPSHOT_DIR)/core-d1
	@rm -f $(SNAPSHOT_DIR)/core-d1/*.sqlite-shm $(SNAPSHOT_DIR)/core-d1/*.sqlite-wal
	@cp -r $(EMAIL_D1_DIR) $(SNAPSHOT_DIR)/email-d1
	@rm -f $(SNAPSHOT_DIR)/email-d1/*.sqlite-shm $(SNAPSHOT_DIR)/email-d1/*.sqlite-wal
	@printf "$(GREEN)Snapshot saved ($$(du -sh $(SNAPSHOT_DIR) | cut -f1))$(RESET)\n"

restore-db: ## Restore D1 from snapshot (< 1 second)
	@if [ ! -d $(SNAPSHOT_DIR)/core-d1 ]; then \
		printf "$(RED)No snapshot found. Run 'make snapshot-db' first.$(RESET)\n"; \
		exit 1; \
	fi
	@printf "$(CYAN)Restoring D1 databases...$(RESET)\n"
	@rm -rf $(CORE_D1_DIR)  && cp -r $(SNAPSHOT_DIR)/core-d1  $(CORE_D1_DIR)
	@rm -rf $(EMAIL_D1_DIR) && cp -r $(SNAPSHOT_DIR)/email-d1 $(EMAIL_D1_DIR)
	@printf "$(GREEN)Restored from snapshot.$(RESET)\n"
```

**Why delete `.sqlite-shm` / `.sqlite-wal` before snapshotting:** those are
SQLite's write-ahead-log sidecars. They contain uncommitted state and vary
machine-to-machine; dropping them gives you a clean, portable snapshot.

**Seeding:** put seed data in a `seed:` target that executes SQL via
`wrangler d1 execute ... --local --command "..."`. Keep it small and
idempotent (`INSERT OR IGNORE` / `INSERT OR REPLACE`).

---

## 7. Port numbering

Pick non-default ports so multiple personal projects can run simultaneously
without collision.

**Convention:** first service of a new project starts at **8787** (the wrangler
default) and increments from there. Vite SPAs pick up from **5174** (Vite's
default 5173 is reserved for ad-hoc `vite` runs). Containers at **8080**.

| Service role            | Port  |
|-------------------------|-------|
| Primary Worker API      | 8787  |
| Secondary Worker (email, auth, etc.) | 8788, 8789, ...       |
| Container / standalone  | 8080  |
| Vite SPA (primary)      | 5174  |
| Vite SPA (secondary)    | 5175  |

If you're running a second project concurrently, bump the whole range by 100
(e.g. `8887` / `8888`) rather than reusing.

---

## 8. Checklist — adding a new service

1. Add a `<NAME>_DIR` / `<NAME>_PORT` / `<NAME>_CMD` block to the variable section.
2. Add `start-<name>:` and `stop-<name>:` targets using the macros.
3. Add the service to `stop:` and `status:` (one line each).
4. Decide whether it should be in `dev` (minimum stack) or only in `start` (full stack).
5. Add `$(<NAME>_PORT)` to the URL list in both `dev:` and `start:`.
6. Add the target names to the single `.PHONY` line at the top.
7. If it has a D1, extend `migrate`, `reset-db`, `snapshot-db`, `restore-db` to cover it.

Takes about 5 minutes end-to-end. The variable block at the top means the
macros pick up the new service without editing the macros themselves.

---

## 9. Out of scope — see sibling skills

- **`secrets-1password`** — `backup-env` / `restore-env` targets, `.dev.vars` / `.env.secrets` conventions
- **`cicd`** — GitHub Actions, release automation
- **`cloudflare-baseline`** — `deploy` / `deploy-<svc>` targets, `wrangler.jsonc`
- **`python-worker`** / **`hono-worker`** — `pyproject.toml` / `package.json` contents

Keep this Makefile focused on **local orchestration**. Deploy and secret targets
go in the same Makefile but the skills that own them live separately.
