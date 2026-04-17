---
name: hono-worker
description: TypeScript Cloudflare Worker conventions for personal SDLC projects — Hono as the HTTP framework, pnpm + TypeScript strict mode, Vitest for tests, wrangler for local dev and deploy. Use when scaffolding, editing, or debugging a TS Worker.
---

# Hono Worker

The default for non-Python Workers in personal projects.

## Stack

- **Hono** — tiny, fast, excellent on Workers
- **TypeScript** — `strict: true`, no `any` unless bridging untyped deps
- **pnpm** via npm workspaces at the monorepo root
- **Vitest** with `@cloudflare/vitest-pool-workers` for Worker-native tests
- **wrangler** for local dev and deploy

## Folder layout

```
apps/<name>/
├── package.json
├── tsconfig.json
├── wrangler.jsonc
├── vitest.config.ts
├── migrations/
│   └── 0001_init.sql
└── src/
    ├── index.ts           # Hono app + default export for CF
    ├── auth.ts
    ├── db.ts              # D1 typed helpers
    ├── routes/            # one file per resource
    ├── schemas/           # Zod — mirror FastAPI Create/Update/Read/ListItem
    └── domain/            # (optional) pure logic
```

## `src/index.ts` shape

```ts
import { Hono } from 'hono';
import type { Env } from './env';

const app = new Hono<{ Bindings: Env }>();

app.get('/version', (c) => c.json({ commit: c.env.GIT_COMMIT ?? 'dev' }));

// Routes mounted at module load — Worker cold-start is already fast enough
// that lazy-loading (like the python-worker does) is not worth the complexity.
import { aufgaben } from './routes/aufgaben';
app.route('/aufgaben', aufgaben);

export default app;
```

## Env types

Type `Env` lives in `src/env.ts` and mirrors the bindings in `wrangler.jsonc`.
Keep it in sync by hand — a single source of truth with `wrangler types` is
possible but adds a build step; hand-maintained is fine at small scale.

## Validation

Zod schemas in `src/schemas/`. For each resource, export `CreateX`, `UpdateX`,
`ReadX`, `ListItemX` — same quadruple as the Python worker to keep mental models
aligned.

## Deployment

```bash
pnpm -F <name> deploy --var GIT_COMMIT:$(git rev-parse --short HEAD)
```

Wired through the root Makefile's `make deploy-<name>` target.

## TODO

- [ ] Full `tsconfig.json` — strict mode, module resolution, CF Workers types
- [ ] Vitest config template with Worker pool
- [ ] Zod helpers (`okSchema`, pagination wrapper)
- [ ] Auth middleware pattern (JWT verify using Web Crypto)
