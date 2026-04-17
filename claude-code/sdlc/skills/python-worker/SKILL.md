---
name: python-worker
description: Python Cloudflare Worker conventions for personal SDLC projects — FastAPI with sqlalchemy-cloudflare-d1, lazy route loading via lifespan for fast cold starts, uv as package manager, pywrangler for local dev. Use when scaffolding, editing, or debugging a Python Worker.
---

# Python Worker

Python on Cloudflare Workers. Reference: `~/code/blackwhite/kaminkommander-core`.

## Stack

- **FastAPI** as the HTTP framework
- **`sqlalchemy-cloudflare-d1`** as the D1 driver
- **Pydantic** for request/response validation
- **PyJWT** for auth
- **uv** as the package manager (not poetry, not pipenv)
- **pywrangler** for local dev (`uv run pywrangler dev`)

## Folder layout

```
apps/<name>/
├── pyproject.toml
├── wrangler.jsonc
├── migrations/
│   └── 0001_init.sql
└── src/
    ├── worker.py          # CF entrypoint
    ├── app.py             # FastAPI factory, lifespan with lazy route loading
    ├── auth.py
    ├── db.py              # SQLAlchemy D1 engine
    ├── r2.py
    ├── version.py
    ├── models/            # SQLAlchemy ORM, one file per aggregate
    ├── routes/            # FastAPI routers, 1:1 with models
    ├── schemas/           # Pydantic Create/Update/Read/ListItem
    └── pdf_mappings/      # (optional) domain → PDF field maps
```

## Lazy route loading

Worker cold-start and memory-snapshot size matter. Route imports go inside
`app.py`'s `lifespan` context manager, not at module top:

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI

@asynccontextmanager
async def lifespan(app: FastAPI):
    from .routes import aufgabe, objekt, befund  # lazy
    app.include_router(aufgabe.router)
    app.include_router(objekt.router)
    app.include_router(befund.router)
    yield

app = FastAPI(lifespan=lifespan)
```

This keeps the initial import graph tiny — route modules (and their heavy
SQLAlchemy/Pydantic imports) only load on the first request.

## Local dev

```bash
cd apps/<name>
uv run pywrangler dev
```

D1 is handled by miniflare automatically — local SQLite under
`.wrangler/state/v3/d1/miniflare-D1DatabaseObject/`. See the `local-dev` skill
for the snapshot/restore pattern.

## Deployment

```bash
uv run pywrangler deploy --var GIT_COMMIT:$(git rev-parse --short HEAD)
```

Always pass `GIT_COMMIT` so the `/version` endpoint can report the deployed sha.

## TODO

- [ ] Full `pyproject.toml` template (dependencies pinned to working versions)
- [ ] `src/app.py` and `src/worker.py` full templates
- [ ] Migration runner — how `migrations/` gets applied in dev vs. prod
- [ ] Test harness (pytest + snapshot restore for isolation)
