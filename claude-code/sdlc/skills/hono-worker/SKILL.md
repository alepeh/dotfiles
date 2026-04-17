---
name: hono-worker
description: TypeScript Cloudflare Worker conventions for personal SDLC projects — Hono as the HTTP framework, strict TS, Vitest with the Workers pool for Worker-native tests, Zod for validation, hand-maintained Env type mirroring wrangler bindings, JWT middleware via Web Crypto. Use whenever scaffolding, editing, or debugging a TS Worker in a personal project.
---

# Hono Worker

The default for non-Python Workers in personal projects. The pattern
leans on what `~/code/blackwhite/kaminkommander-pdf/` proves (strict TS +
`@cloudflare/workers-types` + minimal deps) and adds Hono on top for
routing. Kaminkommander's only TS Worker is the PDF gateway — so some
idioms here (auth middleware, Zod schemas) are conventions rather than
direct ports.

---

## Stack

- **Hono** — tiny, fast, excellent on Workers
- **TypeScript** — `strict: true`, no `any` unless bridging untyped deps
- **pnpm** via npm workspaces at the monorepo root
- **Vitest** with `@cloudflare/vitest-pool-workers` for Worker-native tests
- **Zod** for request/response validation
- **Wrangler** for local dev and deploy

---

## Folder layout

```
apps/<svc>/
├── package.json
├── tsconfig.json
├── wrangler.jsonc           # see cloudflare-baseline skill
├── vitest.config.ts
├── migrations/
│   └── 0001_init.sql
└── src/
    ├── index.ts             # Hono app + default export for CF
    ├── env.ts               # Env type — mirrors wrangler.jsonc bindings
    ├── auth.ts              # JWT middleware
    ├── db.ts                # D1 typed helpers
    ├── routes/              # one file per resource
    │   ├── health.ts
    │   └── <resource>.ts
    ├── schemas/             # Zod — Create/Update/Read/ListItem per resource
    └── domain/              # (optional) pure logic, no I/O
```

---

## `package.json`

```jsonc
{
  "name": "<project>-<svc>",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "test": "vitest run",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "hono": "^4.0.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "@cloudflare/workers-types": "^4.20250109.0",
    "@cloudflare/vitest-pool-workers": "^0.5.0",
    "typescript": "^5.7.0",
    "vitest": "^2.1.0",
    "wrangler": "^4.0.0"
  }
}
```

---

## `tsconfig.json`

Verbatim from kaminkommander-pdf — proven to work on Workers:

```jsonc
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],
    "types": ["@cloudflare/workers-types"],
    "strict": true,
    "noEmit": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*.ts"]
}
```

- `strict: true` — no `any`, no implicit undefined, strict null checks
- `noEmit: true` — Wrangler bundles at dev/deploy time; don't emit JS
- `types: ["@cloudflare/workers-types"]` — the only ambient types we need;
  no Node types (we're not on Node)
- `moduleResolution: "bundler"` — matches what Wrangler/esbuild expect

---

## `src/env.ts` — typed bindings

Hand-maintained, in sync with `wrangler.jsonc`. `wrangler types` can
generate this automatically but adds a build step; hand-maintained is fine
at small scale — when a binding drifts, `tsc --noEmit` catches it.

```ts
export interface Env {
  // D1
  DB: D1Database;

  // R2
  UPLOADS: R2Bucket;
  TEMPLATES: R2Bucket;

  // Service bindings
  EMAIL_SERVICE: Fetcher;

  // Secrets (wrangler secret put)
  JWT_SECRET: string;
  SERVICE_TOKEN: string;

  // Vars (wrangler.jsonc)
  APP_URL: string;
  GIT_COMMIT?: string;   // set by deploy; may be absent locally
}
```

---

## `src/index.ts`

Routes mount at module load — CF Workers cold-start is already fast enough
that lazy loading (which the `python-worker` skill does for snapshot-size
reasons) is not worth the complexity on TS.

```ts
import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import type { Env } from "./env";

import { health } from "./routes/health";
import { resource } from "./routes/resource";

const app = new Hono<{ Bindings: Env }>();

app.use("*", logger());
app.use("*", cors({
  origin: (origin, c) => c.env.APP_URL,
  credentials: true,
}));

app.get("/version", (c) =>
  c.json({ commit: c.env.GIT_COMMIT ?? "dev" })
);

app.route("/health", health);
app.route("/resources", resource);

export default app;
```

Always expose `/version` — the deploy recipe sets `GIT_COMMIT` (see
`cloudflare-baseline` skill). Handy for debugging "is this really what's
deployed" regressions.

---

## `src/auth.ts` — JWT middleware

Web Crypto only — no Node polyfills. Hono gives you `createMiddleware`;
this verifies HS256 tokens against the `JWT_SECRET` binding and sets a
`c.var.userId` the routes can read.

```ts
import { createMiddleware } from "hono/factory";
import { HTTPException } from "hono/http-exception";
import type { Env } from "./env";

type Variables = { userId: string };

export const requireUser = createMiddleware<{
  Bindings: Env;
  Variables: Variables;
}>(async (c, next) => {
  const auth = c.req.header("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    throw new HTTPException(401, { message: "missing bearer token" });
  }
  const token = auth.slice(7);
  const payload = await verifyHS256(token, c.env.JWT_SECRET);
  c.set("userId", payload.sub);
  await next();
});

async function verifyHS256(token: string, secret: string) {
  const [headerB64, payloadB64, sigB64] = token.split(".");
  if (!headerB64 || !payloadB64 || !sigB64) {
    throw new HTTPException(401, { message: "malformed token" });
  }
  const data = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const sig = b64urlToBytes(sigB64);
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const ok = await crypto.subtle.verify("HMAC", key, sig, data);
  if (!ok) throw new HTTPException(401, { message: "invalid signature" });

  const payload = JSON.parse(new TextDecoder().decode(b64urlToBytes(payloadB64)));
  if (payload.exp && Date.now() / 1000 > payload.exp) {
    throw new HTTPException(401, { message: "expired" });
  }
  return payload as { sub: string; exp?: number };
}

function b64urlToBytes(s: string): Uint8Array {
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/");
  const pad = b64.length % 4 === 0 ? "" : "=".repeat(4 - (b64.length % 4));
  return Uint8Array.from(atob(b64 + pad), (c) => c.charCodeAt(0));
}
```

For service-to-service calls, a simpler pattern applies: check a shared
`SERVICE_TOKEN` in the header. Reserve JWT for user-authenticated requests.

---

## `src/schemas/` — Zod

Mirror the Python worker's Create/Update/Read/ListItem quadruple so the
two backends stay shape-aligned.

```ts
// src/schemas/resource.ts
import { z } from "zod";

export const ResourceCreate = z.object({
  name: z.string().min(1).max(200),
  description: z.string().optional(),
});

export const ResourceUpdate = ResourceCreate.partial();

export const ResourceRead = ResourceCreate.extend({
  id: z.string().uuid(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
});

export const ResourceListItem = z.object({
  id: z.string().uuid(),
  name: z.string(),
});

export type ResourceCreate = z.infer<typeof ResourceCreate>;
export type ResourceRead = z.infer<typeof ResourceRead>;
export type ResourceListItem = z.infer<typeof ResourceListItem>;
```

Use Hono's `zValidator` to reject bad requests before they reach the handler:

```ts
import { zValidator } from "@hono/zod-validator";
import { ResourceCreate } from "../schemas/resource";

resource.post("/", zValidator("json", ResourceCreate), async (c) => {
  const body = c.req.valid("json");   // fully typed
  // ...
});
```

---

## `src/routes/<resource>.ts`

One file per resource. The `health` route is minimal; others follow the
same shape.

```ts
import { Hono } from "hono";
import type { Env } from "../env";

export const health = new Hono<{ Bindings: Env }>();

health.get("/", (c) => c.json({ status: "ok" }));
```

Real resources mount a sub-router, include the auth middleware, and
expose CRUD:

```ts
import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";
import { requireUser } from "../auth";
import { ResourceCreate, ResourceUpdate } from "../schemas/resource";
import type { Env } from "../env";

type Variables = { userId: string };

export const resource = new Hono<{ Bindings: Env; Variables: Variables }>();

resource.use("*", requireUser);

resource.get("/", async (c) => {
  // SELECT ... FROM resources WHERE user_id = ?
  const { results } = await c.env.DB.prepare(
    "SELECT id, name FROM resources WHERE user_id = ?",
  ).bind(c.var.userId).all();
  return c.json({ items: results, total: results.length });
});

resource.post("/", zValidator("json", ResourceCreate), async (c) => {
  const body = c.req.valid("json");
  const id = crypto.randomUUID();
  await c.env.DB.prepare(
    "INSERT INTO resources (id, user_id, name, description) VALUES (?, ?, ?, ?)",
  ).bind(id, c.var.userId, body.name, body.description ?? null).run();
  return c.json({ id, ...body }, 201);
});
```

---

## `vitest.config.ts` — Worker-native tests

```ts
import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.jsonc" },
      },
    },
  },
});
```

Tests run inside miniflare with real bindings — the same D1, R2, and
service bindings as dev. This means you can write integration tests
against the Worker without mocking:

```ts
// tests/resource.test.ts
import { SELF } from "cloudflare:test";
import { expect, it } from "vitest";

it("GET /health", async () => {
  const res = await SELF.fetch("https://test/health");
  expect(res.status).toBe(200);
});
```

For tests that need a clean D1 between runs, use the snapshot/restore
pattern from the **local-dev** skill.

---

## Local dev

```bash
# From the monorepo root:
make dev                # orchestrated via Makefile (see local-dev skill)

# Or directly in the app:
cd apps/<svc>
pnpm dev                # wraps wrangler dev
```

Wrangler picks up `.dev.vars` automatically. D1 is local SQLite under
`.wrangler/state/v3/d1/...` — miniflare-managed, no manual setup.

---

## Deployment

Driven by the root Makefile (see `cloudflare-baseline` skill's
"Deployment" section):

```bash
make deploy-<svc>
# → cd apps/<svc> && wrangler deploy --var GIT_COMMIT:<short-sha>
```

The `GIT_COMMIT` var surfaces in `env.GIT_COMMIT` for the `/version`
endpoint.

---

## Out of scope — see sibling skills

- **`cloudflare-baseline`** — `wrangler.jsonc` templates, D1/R2 creation,
  service-binding rationale, deploy recipes
- **`python-worker`** — the Python counterpart (FastAPI, lazy lifespan)
- **`local-dev`** — Makefile macros, orchestration, D1 snapshot/restore
- **`secrets-1password`** — `.dev.vars` lifecycle, backup-env/restore-env
- **`cicd`** — typecheck in CI, Vitest in CI
