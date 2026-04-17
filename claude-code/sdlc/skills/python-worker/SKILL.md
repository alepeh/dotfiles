---
name: python-worker
description: Python Cloudflare Worker conventions for personal SDLC projects — FastAPI with sqlalchemy-cloudflare-d1, uv as the package manager, pywrangler for local dev and deploy, lazy route loading via FastAPI lifespan to keep the CF Python Workers memory snapshot small, async-def everywhere (Pyodide can't spawn threads). Use whenever scaffolding, editing, or debugging a Python Worker.
---

# Python Worker

Python on Cloudflare Workers. Reference: `~/code/blackwhite/kaminkommander-core`
and `~/code/blackwhite/kaminkommander-email`. Everything here is verbatim
or very close to kaminkommander's conventions — these are battle-tested on
a production CF Python Worker with 25+ route modules.

---

## Stack

- **FastAPI** as the HTTP framework
- **`sqlalchemy-cloudflare-d1`** as the D1 driver (wraps D1 as a SQLAlchemy
  async engine)
- **Pydantic** for request/response validation
- **PyJWT** for auth
- **uv** as the package manager (not poetry, not pipenv — uv is fast and
  plays well with CF Python Workers' pyodide lifecycle)
- **pywrangler** for local dev and deploy (not plain `wrangler`)

---

## Folder layout

```
apps/<svc>/
├── pyproject.toml
├── wrangler.jsonc           # see cloudflare-baseline skill
├── migrations/
│   ├── 0001_init.sql
│   └── 0002_add_feature_table.sql
└── src/
    ├── worker.py            # CF entrypoint — bridges to ASGI
    ├── app.py               # FastAPI factory with lazy-lifespan route loading
    ├── auth.py              # JWT + service-token validation
    ├── db.py                # SQLAlchemy D1 engine (per-request)
    ├── version.py           # __version__ — bumped by `make release`
    ├── models/              # SQLAlchemy ORM, one file per aggregate
    │   ├── __init__.py
    │   └── <entity>.py
    ├── routes/              # FastAPI routers, 1:1 with models
    │   ├── __init__.py
    │   ├── health.py
    │   └── <resource>.py
    └── schemas/             # Pydantic Create/Update/Read/ListItem
        ├── __init__.py
        └── <resource>.py
```

The 1:1 `models/` ↔ `routes/` ↔ `schemas/` parallelism is load-bearing
(see **ddd-layout** skill). `tests/` sits at `apps/<svc>/tests/`.

---

## `pyproject.toml`

```toml
[project]
name = "<project>-<svc>"
version = "0.1.0"
description = "<short description>"
requires-python = ">=3.12"
dependencies = [
    "fastapi",
    "pydantic",
    "pyjwt",
    "python-multipart",
    "sqlalchemy",
    "sqlalchemy-cloudflare-d1",
]

[dependency-groups]
dev = [
    "pywrangler",
]
test = [
    "pytest",
    "httpx",
]

[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["src", "tests"]
```

Pin Python to 3.12 — that's what the CF Python Workers runtime uses. Newer
Python versions aren't supported at the edge yet.

Install deps:

```bash
uv sync
```

---

## `src/worker.py` — CF Workers entrypoint

Verbatim from kaminkommander — this is just the ASGI bridge:

```python
"""Cloudflare Worker entrypoint — bridges Workers runtime to FastAPI via ASGI."""

import asgi
from workers import WorkerEntrypoint

from app import app


class Default(WorkerEntrypoint):
    """CF Workers Python entrypoint.

    The `fetch` method is called for every HTTP request.
    `env` carries D1 bindings and other CF resources.
    """

    async def fetch(self, request):
        return await asgi.fetch(app, request, self.env)
```

`asgi` and `workers` are provided by the CF Python Workers runtime — don't
install them.

---

## `src/app.py` — lazy-lifespan FastAPI factory

This is the non-obvious one. **Do not import route modules at top level.**

CF Python Workers create a pyodide memory snapshot at deploy time by
executing the module's top-level imports. With 25+ route modules (each
pulling in Pydantic schemas + SQLAlchemy models), the snapshot creation
exceeds the platform's internal timeout and the deploy fails.

Defer imports to first-request via FastAPI's `lifespan`:

```python
"""FastAPI application factory with lazy route loading.

Cloudflare Python Workers create a memory snapshot by executing top-level
imports at deploy time. With many route modules (each importing schemas
and models), the snapshot creation exceeds the platform's internal timeout.

Using importlib inside a lifespan startup event defers route registration
to first-request time, keeping the snapshot small and deploy fast.
"""

import importlib
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# (module_path, attribute_name) — registered in order at startup
_ROUTE_MODULES = [
    ("routes.health", "router"),
    ("routes.auth", "router"),
    ("routes.resource", "router"),
    # Add one line per route module. Order doesn't matter beyond health-first
    # for `/health` to work before everything else is imported.
]


_routes_registered = False


def _register_routes(application: FastAPI) -> None:
    """Import route modules and register their routers (once only)."""
    global _routes_registered
    if _routes_registered:
        return
    for module_path, attr_name in _ROUTE_MODULES:
        mod = importlib.import_module(module_path)
        router = getattr(mod, attr_name)
        application.include_router(router)
    _routes_registered = True


@asynccontextmanager
async def lifespan(application: FastAPI):
    _register_routes(application)
    yield


app = FastAPI(
    title="<Project> <Svc> API",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],    # tighten per project
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

Every time you add a new route module, append a line to `_ROUTE_MODULES`.
That's it — the lifespan handles registration automatically.

---

## `src/db.py` — per-request SQLAlchemy engine

Verbatim from kaminkommander. **All dependencies must be `async def`** —
CF Workers Python is pyodide-based and cannot spawn threads, so sync
dependencies fail with "RuntimeError: can't start new thread" when FastAPI
tries `run_in_threadpool()`.

```python
"""Database dependency — creates a SQLAlchemy engine from the D1 binding per request.

IMPORTANT: All dependencies must be `async def` on CF Workers Python.
Pyodide cannot spawn threads, so sync `def` dependencies fail with
"RuntimeError: can't start new thread" when FastAPI tries run_in_threadpool().
"""

from fastapi import Request
from sqlalchemy_cloudflare_d1 import create_engine_from_binding


async def get_engine(request: Request):
    """Create a SQLAlchemy engine from the D1 binding.

    The engine is created per-request because the D1 binding
    is only available inside a request context on CF Workers.
    """
    d1 = request.scope["env"].DB
    return create_engine_from_binding(d1)
```

Use it in routes:

```python
from fastapi import Depends
from sqlalchemy import text

from db import get_engine


@router.get("/")
async def list_resources(engine=Depends(get_engine)):
    async with engine.connect() as conn:
        result = await conn.execute(text("SELECT id, name FROM resources"))
        rows = result.fetchall()
    return {"items": [dict(r._mapping) for r in rows]}
```

---

## `src/models/<entity>.py` — SQLAlchemy ORM

One file per aggregate. Keep tables thin; denormalize computed columns
into list-endpoint responses via schemas, not the DB.

```python
from sqlalchemy import Column, String, Text
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class Resource(Base):
    __tablename__ = "resources"

    id = Column(String, primary_key=True)
    user_id = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    created_at = Column(String, nullable=False)
    updated_at = Column(String, nullable=False)
```

D1/SQLite conventions (from **ddd-layout** skill):
- Primary keys are TEXT (UUIDs), not INTEGER
- Datetimes are ISO 8601 TEXT, not SQLite TIMESTAMP
- Enums are TEXT with CHECK constraints
- Don't declare `FOREIGN KEY` — D1 doesn't enforce reliably; enforce in app code

---

## `src/schemas/<resource>.py` — Pydantic

The Create/Update/Read/ListItem quadruple — mirrors the TS worker's Zod
pattern:

```python
from pydantic import BaseModel, Field


class ResourceCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    description: str | None = None


class ResourceUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=200)
    description: str | None = None


class ResourceRead(BaseModel):
    id: str
    name: str
    description: str | None
    created_at: str
    updated_at: str


class ResourceListItem(BaseModel):
    id: str
    name: str
```

---

## `src/routes/<resource>.py`

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text

from db import get_engine
from schemas.resource import ResourceCreate, ResourceRead

router = APIRouter(prefix="/api/resources", tags=["resources"])


@router.get("/")
async def list_resources(engine=Depends(get_engine)) -> dict:
    async with engine.connect() as conn:
        result = await conn.execute(text("SELECT id, name FROM resources"))
        rows = result.fetchall()
    return {"items": [dict(r._mapping) for r in rows], "total": len(rows)}


@router.post("/", response_model=ResourceRead, status_code=201)
async def create_resource(body: ResourceCreate, engine=Depends(get_engine)):
    # ...
    pass
```

Remember to add `("routes.resource", "router")` to `_ROUTE_MODULES` in `app.py`.

---

## Migrations

Sequential SQL files under `migrations/`:

```
migrations/
├── 0001_create_resource_table.sql
├── 0002_add_resource_tags.sql
└── 0003_backfill_tags.sql
```

Apply locally:

```bash
cd apps/<svc>
uv run pywrangler d1 migrations apply <project>-<svc>-db --local
```

Apply to prod (manual, after `make deploy-<svc>`):

```bash
uv run pywrangler d1 migrations apply <project>-<svc>-db --remote
```

**Rules** (from **ddd-layout** and kaminkommander's guidelines.md):
- Never modify a deployed migration — add a new one
- Always additive; breaking migrations require an ADR (see **change-protocol**)
- D1 doesn't reliably enforce `FOREIGN KEY` — don't declare them

---

## Local dev

```bash
cd apps/<svc>
uv run pywrangler dev
```

Or via the root Makefile (preferred — handles ports + logs uniformly):

```bash
make dev
```

miniflare handles the D1 binding. Local SQLite lives under
`.wrangler/state/v3/d1/miniflare-D1DatabaseObject/` — see the **local-dev**
skill for the snapshot/restore pattern.

---

## Testing

Pytest with the test D1 snapshot pattern. Tests run outside the Worker
runtime (pyodide isn't needed for the HTTP surface); use `httpx` to hit
the FastAPI app directly.

```python
# tests/test_resource.py
import pytest
from httpx import AsyncClient

from app import app


@pytest.mark.asyncio
async def test_list_resources_empty():
    async with AsyncClient(app=app, base_url="http://test") as client:
        response = await client.get("/api/resources/")
    assert response.status_code == 200
    assert response.json() == {"items": [], "total": 0}
```

For tests that need D1 bindings, stub `request.scope["env"].DB` with an
in-memory SQLAlchemy engine. That keeps tests fast — the D1 binding is
only a driver; the SQL surface is standard SQLite.

---

## Deployment

Driven by the root Makefile (see **cloudflare-baseline** skill's
"Deployment" section):

```bash
make deploy-<svc>
# → cd apps/<svc> && uv run pywrangler deploy --var GIT_COMMIT:<short-sha>
```

Read `GIT_COMMIT` in the `/version` endpoint:

```python
# src/routes/health.py
from fastapi import APIRouter, Request

router = APIRouter()


@router.get("/version")
async def version(request: Request):
    env = request.scope["env"]
    return {
        "commit": getattr(env, "GIT_COMMIT", "dev"),
        "version": __version__,
    }
```

---

## Gotchas specific to CF Python Workers

- **Async everywhere.** No threads, no sync `def` dependencies.
- **Lazy imports.** Anything at module top-level runs during snapshot
  creation. Keep that graph small.
- **No filesystem in prod.** miniflare gives you one locally; prod is
  read-only. Write to R2 or D1.
- **pyodide stdlib is complete enough.** Most pure-Python deps work.
  C-extension deps (psycopg2, numpy wheels) don't.
- **`pywrangler` not `wrangler`.** Plain wrangler doesn't resolve Python
  imports correctly. Always use the Python variant for dev and deploy.

---

## Out of scope — see sibling skills

- **`cloudflare-baseline`** — `wrangler.jsonc` template, D1/R2 creation,
  `pywrangler` vs `wrangler` matrix, deploy recipes
- **`hono-worker`** — the TS counterpart
- **`local-dev`** — Makefile macros, orchestration, D1 snapshot/restore
- **`secrets-1password`** — `.dev.vars` lifecycle, backup-env/restore-env
- **`ddd-layout`** — models/routes/schemas convention, domain-model.md template
- **`cicd`** — pytest in CI
