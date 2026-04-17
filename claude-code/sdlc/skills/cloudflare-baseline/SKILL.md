---
name: cloudflare-baseline
description: Cloudflare infrastructure defaults for personal projects — wrangler.jsonc structure, D1/R2/KV/Durable-Object bindings, service bindings for Worker-to-Worker calls, routing to custom domains on pehm.co.at. Use whenever scaffolding, editing, or troubleshooting a Cloudflare Worker or Pages project outside work.
---

# Cloudflare baseline

Opinionated defaults for Cloudflare Workers / Pages / D1 / R2, lifted from
`~/code/blackwhite/kaminkommander`. Mirror that reference when in doubt.

## wrangler.jsonc shape

Use `.jsonc` not `.toml`. Required top-level keys:

- `name` — lowercase, hyphenated, matches the app directory
- `main` — `src/index.ts` for Hono, `src/worker.py` for Python
- `compatibility_date` — today's date in YYYY-MM-DD
- `compatibility_flags` — `["python_workers"]` for Python only
- `routes` — if a custom domain is configured:
  `[{ "pattern": "<name>.pehm.co.at/*", "zone_name": "pehm.co.at" }]`

## Bindings

- **D1**: `{ "binding": "DB", "database_name": "<name>-db", "database_id": "...", "migrations_dir": "migrations" }`
- **R2**: one bucket per logical concern (`IMAGES`, `TEMPLATES`, `UPLOADS`) — don't share buckets across satellites
- **Service bindings**: prefer over HTTP for Worker-to-Worker calls (zero latency, no DNS, no same-zone 522s)
- **Durable Objects**: only for stateful coordination or container pools (see `~/code/blackwhite/kaminkommander-pdf/`)
- **KV**: avoid by default — D1 is almost always the right choice

## vars vs secrets

- `vars` in wrangler.jsonc — public config (service URLs, region, sender email)
- `wrangler secret put <NAME>` — anything sensitive (JWT secrets, API keys)
- Locally: `.dev.vars` (gitignored) for the same keys; `.env.secrets.example` (committed) for the manifest

## Satellite pattern

When a service is logically distinct (email, PDF generation, auth), give it its
own Worker + its own D1 + a service binding back to the primary service. Do
not reuse the primary D1 — satellites stay stateless against the core domain
and keep their own small tables (templates, settings, logs).

## TODO

- [ ] Embed full `wrangler.jsonc` templates for TS worker / Python worker / Pages / container-gateway
- [ ] Document the `pywrangler` install step and when to use it vs. `wrangler`
- [ ] Add `make deploy` pattern including `--var GIT_COMMIT:$(git rev-parse --short HEAD)`
