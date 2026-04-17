---
name: cloudflare-baseline
description: Cloudflare infrastructure defaults for personal projects — wrangler.jsonc templates for TS Hono Workers, Python FastAPI Workers, Pages SPAs, and Container gateways; D1/R2/service-binding/Durable-Object conventions; custom-domain routing on pehm.co.at; make deploy recipes with git-sha injection. Use whenever scaffolding a new Worker/Pages app, editing wrangler config, adding a binding, or debugging a Cloudflare deploy.
---

# Cloudflare baseline

Opinionated defaults for Cloudflare Workers / Pages / D1 / R2 / Containers /
Durable Objects. Lifted from `~/code/blackwhite/kaminkommander`. Mirror that
reference when in doubt.

---

## The shape

- **One `wrangler.jsonc` per app.** `apps/<svc>/wrangler.jsonc`. No shared
  config, no env-switching inside a single file — different deployables
  get different files.
- **`.jsonc`, not `.toml`.** JSONC is what the `/sdlc:bootstrap` scaffold
  uses and what kaminkommander uses. TOML works but the tooling story around
  comments and schema validation is weaker.
- **Always set these top-level keys:**
  - `name` — lowercase, hyphenated, matches the app directory
  - `main` — `src/index.ts` (Hono) or `src/worker.py` (Python)
  - `compatibility_date` — today's date in YYYY-MM-DD at scaffold time
  - `compatibility_flags` — `["python_workers"]` for Python only; otherwise omit

---

## Template 1 — TS Worker (Hono)

`apps/<svc>/wrangler.jsonc`:

```jsonc
{
  "name": "<project>-<svc>",
  "main": "src/index.ts",
  "compatibility_date": "2026-04-17",

  // Dev server port (per-project convention — see local-dev skill)
  "dev": { "port": 8787 },

  // Custom domain — only if configured. Remove for *.workers.dev.
  "routes": [
    { "pattern": "<svc>.pehm.co.at/*", "zone_name": "pehm.co.at" }
  ],

  // D1 — project's primary database
  "d1_databases": [
    {
      "binding": "DB",
      "database_name": "<project>-<svc>-db",
      "database_id": "<run-once: wrangler d1 create>",
      "migrations_dir": "migrations"
    }
  ],

  // R2 — one bucket per logical concern, never share across satellites
  "r2_buckets": [
    { "binding": "UPLOADS",   "bucket_name": "<project>-uploads" },
    { "binding": "TEMPLATES", "bucket_name": "<project>-templates" }
  ],

  // Service bindings — Worker-to-Worker (zero latency, no DNS)
  "services": [
    { "binding": "EMAIL_SERVICE", "service": "<project>-email" }
  ],

  // Public config. Secrets go through `wrangler secret put`.
  "vars": {
    "APP_URL": "https://<svc>.pehm.co.at"
  }
}
```

`src/index.ts` scaffold + auth/Zod/middleware patterns live in the
**hono-worker** skill.

---

## Template 2 — Python Worker (FastAPI + pywrangler)

`apps/<svc>/wrangler.jsonc`:

```jsonc
{
  "name": "<project>-<svc>",
  "main": "src/worker.py",
  "compatibility_date": "2026-04-17",
  "compatibility_flags": ["python_workers"],

  "dev": { "port": 8787 },

  "routes": [
    { "pattern": "<svc>.pehm.co.at/*", "zone_name": "pehm.co.at" }
  ],

  "d1_databases": [
    {
      "binding": "DB",
      "database_name": "<project>-<svc>-db",
      "database_id": "<run-once: wrangler d1 create>",
      "migrations_dir": "migrations"
    }
  ],

  "r2_buckets": [
    { "binding": "UPLOADS", "bucket_name": "<project>-uploads" }
  ],

  "services": [
    { "binding": "PDF_SERVICE",   "service": "<project>-pdf" },
    { "binding": "EMAIL_SERVICE", "service": "<project>-email" }
  ],

  "vars": {
    "APP_URL": "https://<svc>.pehm.co.at"
  }
}
```

**Key differences from TS:**
- `main` is `src/worker.py`
- `compatibility_flags` must include `"python_workers"`
- Dev uses `pywrangler dev` (from the `sqlalchemy-cloudflare-d1` package),
  not `wrangler dev` — see **python-worker** skill

---

## Template 3 — Pages SPA (vanilla JS + Vite)

Pages doesn't use `wrangler.jsonc` the same way Workers does — the config is
minimal and most of the project lives in `package.json` + `vite.config.js`.

`apps/<spa>/package.json`:

```jsonc
{
  "name": "<project>-<spa>",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "test:e2e": "playwright test"
  },
  "devDependencies": {
    "vite": "^6.0.0",
    "@playwright/test": "^1.50.0"
  }
}
```

Deploy via `wrangler pages deploy`:

```makefile
deploy-<spa>: ## Deploy <spa> to CF Pages
	@VITE_API_URL=$(PROD_API_URL) npx vite build apps/<spa>
	@npx wrangler pages deploy apps/<spa>/dist --project-name=<project>-<spa>
```

Create the Pages project once via the CF dashboard or `wrangler pages project
create <project>-<spa>`. Subsequent deploys just push the `dist/` directory.

Folder layout + routing/state patterns live in the (future) **vanilla-spa**
skill — for now, model on `~/code/blackwhite/kaminkommander-app/`.

---

## Template 4 — Container gateway (Durable Object pool)

For heavy/stateful Python jobs (PDF generation, ML inference, anything not
fitting the Worker CPU budget). A thin TS Worker owns a Durable Object class
that manages a pool of Container instances. The actual work happens inside
the container.

`apps/<svc>/wrangler.jsonc`:

```jsonc
{
  "name": "<project>-<svc>",
  "main": "src/index.ts",
  "compatibility_date": "2026-04-17",

  "containers": [
    {
      "class_name": "<Svc>Container",
      "image": "./container/Dockerfile",
      "max_instances": 3
    }
  ],

  "durable_objects": {
    "bindings": [
      {
        "name": "<SVC>_CONTAINER",
        "class_name": "<Svc>Container"
      }
    ]
  },

  "migrations": [
    {
      "tag": "v1",
      "new_sqlite_classes": ["<Svc>Container"]
    }
  ],

  "vars": {
    "R2_ENDPOINT": "https://<account-id>.r2.cloudflarestorage.com",
    "R2_BUCKET_OUTPUT": "<project>-output"
  }

  // Secrets (wrangler secret put):
  //   <SVC>_SERVICE_TOKEN  — callers must present this
  //   R2_ACCESS_KEY
  //   R2_SECRET_KEY
}
```

Layout:

```
apps/<svc>/
├── wrangler.jsonc
├── src/
│   └── index.ts          # tiny gateway — routes requests to Durable Object
└── container/
    ├── Dockerfile
    ├── main.py           # Python standalone service
    └── requirements.txt
```

Reference: `~/code/blackwhite/kaminkommander-pdf/`.

Primary Workers call this via a service binding, not HTTP — the
`<SVC>_CONTAINER` Durable Object is exposed through the TS gateway, and
sibling Workers bind to the gateway Worker.

---

## D1 — configuration

### Creating a database

Run once, per database, at the project root:

```bash
wrangler d1 create <project>-<svc>-db
```

The output includes a UUID — paste it into `database_id` in `wrangler.jsonc`.
This ID is the only non-idempotent piece of configuration; commit it.

### Migrations

- Live in `apps/<svc>/migrations/` as sequential `NNNN_description.sql`
- Applied locally via `make migrate` → `wrangler d1 migrations apply --local`
- Applied to prod as part of `wrangler deploy` only if you wire it; usually
  run manually after deploy so migrations aren't silently rolled forward
- Always additive. Breaking migrations require an ADR (see
  **change-protocol** skill)

### Local dev

Miniflare stores local SQLite at
`.wrangler/state/v3/d1/miniflare-D1DatabaseObject/`. The **local-dev** skill
owns the snapshot/restore recipe for fast reset.

---

## R2 — buckets

### Naming

`<project>-<concern>`. Examples:

- `<project>-uploads` — user-uploaded files
- `<project>-templates` — static templates the app renders
- `<project>-output` — generated artifacts (PDFs, exports, reports)

### Why one bucket per concern

- Lifecycle policies differ (templates never expire; generated output
  expires after 30d)
- Access patterns differ (templates are public-via-Worker-CDN; uploads are
  private)
- Satellites shouldn't share buckets with the primary Worker — if the
  email Worker needs to stash attachment copies, give it its own
  `<project>-email-attachments`

### Creating a bucket

```bash
wrangler r2 bucket create <project>-<concern>
```

Bindings in `wrangler.jsonc` pick them up by `bucket_name` — no UUID
indirection like D1.

---

## Service bindings — why, not HTTP

Between Workers in the same account, **always use service bindings.** Never
use `fetch("https://other-worker.workers.dev/...")`.

| Concern          | Service binding                   | HTTP fetch                          |
|------------------|-----------------------------------|-------------------------------------|
| Latency          | Zero (same process hop)           | Real network round-trip             |
| DNS              | Not involved                      | Resolves, caches, can fail          |
| Same-zone quirks | None                              | 522 errors on same-zone self-fetch  |
| Cost             | No egress charge                  | Billed bandwidth                    |
| Failure mode     | Clear error from the CF runtime   | Timeouts, DNS flakes, TLS issues    |

Call shape from the binding side:

```ts
// in a Hono Worker:
const response = await env.EMAIL_SERVICE.fetch("https://email/send", {
  method: "POST",
  body: JSON.stringify(payload),
});
```

The hostname in the URL is cosmetic when using a binding — it just needs to
parse. Use a distinctive host like `https://email/send` so service-binding
calls are visibly different from external fetches in logs.

---

## Durable Objects — when to use

Narrow use cases. In this baseline, **use only when you need:**

1. **Container coordination** — the container-gateway pattern above owns
   a DO class to pool Container instances
2. **Single-point serialization** — a chat room, a lock, a counter that
   must be strictly monotonic
3. **Per-entity state that can't fit D1** — rare; usually D1 is fine

**Do not use** for:
- Caching (that's KV or the Cache API)
- General key-value storage (that's D1 or KV)
- Coordinating between different Workers that should have been service bindings

Durable Object migrations (`"migrations": [...]` in wrangler.jsonc) are
schema-level, separate from D1 migrations, and required whenever you add
a new DO class.

---

## KV — avoid by default

D1 is almost always the right choice. KV is fine for:
- Global config that rarely changes (feature flags read on every request)
- Session tokens if you really need <10ms reads

Don't reach for KV as a D1 substitute. It's eventually consistent, has a
1MB value cap, and lacks queries.

---

## Routes and custom domains

Zone `pehm.co.at` is set up once in the CF dashboard. From there, Worker
routing is per-worker:

```jsonc
"routes": [
  { "pattern": "<svc>.pehm.co.at/*", "zone_name": "pehm.co.at" }
]
```

**Pattern conventions:**
- Primary API: `core.<domain>/*` — or just `<project>.<domain>/*` for
  single-service projects
- Satellites: `<service>.<domain>/*` — e.g. `email.`, `pdf.`, `auth.`
- SPAs (Pages): use the Pages project's `.pages.dev` subdomain in dev; wire
  a custom domain in the CF dashboard once stable

For projects without a custom domain, omit `routes` entirely — the Worker
is reachable at `<name>.<account>.workers.dev`.

---

## compatibility_date and compatibility_flags

- **`compatibility_date`** — pin to the bootstrap date. Only bump when you
  need a specific runtime feature (documented per release at
  `https://developers.cloudflare.com/workers/platform/compatibility-dates`).
  Bumping without a reason invites subtle breakage.
- **`compatibility_flags`** — only flag actually needed for this baseline is
  `"python_workers"`. Don't accumulate flags; each one is a surface area
  your code relies on.

---

## vars vs secrets

| Kind              | Where                           | Example                                                |
|-------------------|---------------------------------|--------------------------------------------------------|
| Public config     | `vars` in wrangler.jsonc (committed) | `APP_URL`, `REGION`, `EMAIL_FROM`                 |
| Sensitive         | `wrangler secret put <NAME>`    | `JWT_SECRET`, API keys, service tokens                 |
| Local dev (both)  | `.dev.vars` (gitignored)        | Mirror the keys; miniflare reads this automatically    |
| Manifest          | `.env.secrets.example` (committed) | List of all secret keys with blank values           |

The **secrets-1password** skill owns the backup/restore of `.dev.vars` and
`.env.secrets`. Production secrets live only in Cloudflare — 1Password does
not mirror production.

---

## Satellite pattern — when to split off a Worker

When a service is **logically distinct** (email, PDF generation, auth
provider, payment webhooks), give it its own:

- Worker (`apps/<svc>/`)
- D1 (small, scoped to that service — templates, preferences, audit logs)
- R2 bucket (if it handles blobs)
- Service binding from the primary Worker

**Do not reuse the primary D1.** The whole point of a satellite is that it
stays stateless against the primary domain — it has its own tables and
doesn't need to join against the primary's. If you find yourself wanting a
cross-D1 JOIN, the split is wrong.

**Do not call it over HTTP.** Always service binding.

---

## Deployment

```makefile
PROD_API_URL := https://<project>.pehm.co.at

deploy: deploy-<svc-1> deploy-<svc-2> deploy-<spa>  ## Deploy everything

deploy-<svc>: ## Deploy <svc> to CF Workers
	@printf "$(CYAN)Deploying <svc>...$(RESET)\n"
	@cd apps/<svc> && wrangler deploy --var GIT_COMMIT:$(shell git rev-parse --short HEAD)
	@printf "$(GREEN)<svc> deployed.$(RESET)\n"
```

For Python Workers, substitute `wrangler` with `uv run pywrangler`:

```makefile
deploy-<py-svc>:
	@cd apps/<py-svc> && uv run pywrangler deploy --var GIT_COMMIT:$(shell git rev-parse --short HEAD)
```

**Always pass `GIT_COMMIT`.** This lets the Worker's `/version` endpoint
report the deployed SHA for debugging prod regressions. Read it in code
via `env.GIT_COMMIT`.

**Never automate deploy in CI.** See the **cicd** skill — deploys are
manual in this baseline.

---

## `pywrangler` vs `wrangler`

For Python Workers (FastAPI + sqlalchemy-cloudflare-d1), use `pywrangler`
instead of `wrangler`:

| Command                  | TS Workers               | Python Workers                  |
|--------------------------|--------------------------|--------------------------------|
| Local dev                | `wrangler dev`           | `uv run pywrangler dev`        |
| Deploy                   | `wrangler deploy`        | `uv run pywrangler deploy`     |
| D1 migrations (local)    | `wrangler d1 migrations apply --local` | `uv run pywrangler d1 migrations apply --local` |
| Secrets                  | `wrangler secret put`    | `wrangler secret put` (same — no pywrangler wrapper) |

`pywrangler` handles the Python-specific import resolution. If you run
`wrangler dev` against a Python Worker, it'll mostly work but miss some
import-path quirks. Always the Python variant.

---

## Out of scope — see sibling skills

- **`hono-worker`** — TS Worker source layout (`src/index.ts`,
  `tsconfig.json`, Vitest config, Zod helpers, JWT middleware)
- **`python-worker`** — Python Worker source layout (`pyproject.toml`,
  `src/app.py`, lazy lifespan import pattern, test harness)
- **`scaleway-email`** — full email-satellite wiring (Scaleway API call,
  TEST_MODE flag, unsubscribe tokens)
- **`local-dev`** — Makefile macros, `.dev/` runtime dir, D1 snapshot/restore
- **`secrets-1password`** — `.dev.vars` lifecycle, backup-env/restore-env
- **`cicd`** — CI workflow; why prod deploys stay manual
