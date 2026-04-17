---
name: scaleway-email
description: Email-sending pattern for personal SDLC projects — a dedicated satellite Worker that owns Scaleway API calls, its own D1 for templates/preferences/settings, service binding from the primary Worker, TEST_MODE stored in a single-row settings table so it's toggleable without redeploy, GDPR-compliant unsubscribe tokens. Use when adding email to a project, editing the email Worker, migrating from another provider, or debugging email delivery.
---

# Scaleway email

Email lives in a **dedicated satellite Worker**, never inline in the primary
service. This is the single biggest architectural payoff of the satellite
pattern (see **cloudflare-baseline** skill) — isolating the Scaleway API,
email templates, rate limits, and GDPR unsubscribe state keeps the primary
Worker clean.

Reference: `~/code/blackwhite/kaminkommander-email/`. Everything here is a
direct port with German-domain specifics stripped.

---

## Why a satellite

- **Isolates Scaleway credentials and rate limits.** If the provider throttles,
  it throttles email, not the primary API.
- **Own D1** for templates, preferences, unsubscribe tokens, and settings.
  Doesn't pollute the primary D1 schema.
- **Provider-pluggable.** Swap Scaleway for Resend / Postmark / SES by
  dropping in a new `providers/<name>.py` — the rest of the Worker stays put.
- **TEST_MODE as DB state.** Toggleable from an admin endpoint without
  redeploy.

---

## Wiring

### Primary Worker's `wrangler.jsonc`:

```jsonc
"services": [
  { "binding": "EMAIL_SERVICE", "service": "<project>-email" }
]
```

Call via `env.EMAIL_SERVICE.fetch(...)` — service binding, no HTTP
round-trip (see **cloudflare-baseline** skill for why).

### Email Worker's `wrangler.jsonc`:

```jsonc
{
  "name": "<project>-email",
  "main": "src/worker.py",
  "compatibility_date": "2026-04-17",
  "compatibility_flags": ["python_workers"],

  "dev": { "port": 8788 },

  "routes": [
    { "pattern": "email.pehm.co.at/*", "zone_name": "pehm.co.at" }
  ],

  "d1_databases": [
    {
      "binding": "DB",
      "database_name": "<project>-email-db",
      "database_id": "<run-once: wrangler d1 create>",
      "migrations_dir": "migrations"
    }
  ],

  "services": [
    { "binding": "CORE_SERVICE", "service": "<project>-core" }
  ],

  "vars": {
    "CORE_API_URL": "https://core.pehm.co.at",
    "SCALEWAY_REGION": "fr-par",
    "EMAIL_FROM": "office@pehm.co.at",
    "EMAIL_FROM_NAME": "<sender name>",
    "EMAIL_REPLY_TO": "office@pehm.biz",
    "UNSUBSCRIBE_BASE_URL": "https://email.pehm.co.at"
  }

  // Secrets (wrangler secret put):
  //   SERVICE_TOKEN          — callers must present this in X-Service-Token
  //   CORE_API_URL           — for fetch-mode fallback
  //   CORE_SERVICE_TOKEN     — to call back into core
  //   SCALEWAY_PROJECT_ID
  //   SCALEWAY_SECRET_KEY
}
```

A **back-binding to core** is common — e.g. the unsubscribe endpoint
resolves an email to a user ID via core's API.

---

## Folder layout

Matches **python-worker** skill conventions:

```
apps/email/
├── pyproject.toml
├── wrangler.jsonc
├── migrations/
│   ├── 0001_create_email_preference_table.sql
│   ├── 0002_create_email_template_table.sql
│   └── 0003_create_email_settings_table.sql
└── src/
    ├── worker.py
    ├── app.py                   # FastAPI factory (lazy lifespan — see python-worker)
    ├── auth.py
    ├── db.py
    ├── providers/
    │   └── scaleway.py          # THE ONLY FILE that calls Scaleway
    ├── template_renderer.py
    ├── models/
    │   ├── email_preference.py
    │   ├── email_template.py
    │   └── email_settings.py
    ├── routes/
    │   ├── send.py              # POST /api/send
    │   ├── templates.py         # CRUD /api/templates
    │   ├── preferences.py       # CRUD /api/preferences
    │   ├── settings.py          # GET/PATCH /api/settings (TEST_MODE)
    │   └── unsubscribe.py       # GET /unsubscribe/{token}
    └── schemas/
        └── ...                  # Pydantic per resource
```

Swap providers by adding a sibling to `providers/scaleway.py` — nothing
else moves.

---

## Migrations

### `migrations/0001_create_email_preference_table.sql`

GDPR-compliant unsubscribe state. Token is per-email, unguessable.

```sql
-- Email preference table for GDPR-compliant unsubscribe handling.
-- Tracks customer opt-out status with secure tokens for unsubscribe links.

CREATE TABLE email_preference (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL UNIQUE,
    unsubscribe_token TEXT NOT NULL UNIQUE,
    unsubscribed INTEGER NOT NULL DEFAULT 0,
    unsubscribed_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_email_preference_email ON email_preference(email);
CREATE INDEX idx_email_preference_token ON email_preference(unsubscribe_token);
CREATE INDEX idx_email_preference_unsubscribed ON email_preference(unsubscribed);
```

### `migrations/0002_create_email_template_table.sql`

Handlebars / Jinja2 source stored here; rendered per send.

```sql
CREATE TABLE email_template (
    id TEXT PRIMARY KEY,                 -- UUID; stable across edits
    name TEXT NOT NULL UNIQUE,           -- stable identifier: "reminder", "welcome"
    subject TEXT NOT NULL,               -- with {{ variable }} placeholders
    body_text TEXT NOT NULL,             -- plain-text body with placeholders
    description TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### `migrations/0003_create_email_settings_table.sql`

Single-row config table — TEST_MODE lives here so it can be toggled from an
admin endpoint without redeploying. Lifted verbatim from kaminkommander.

```sql
-- Email service settings (single-row config table).
-- Test mode redirects all outgoing emails to the test recipient.

CREATE TABLE email_settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    test_mode INTEGER NOT NULL DEFAULT 0,
    test_recipient TEXT,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Seed default row (test mode off)
INSERT INTO email_settings (id, test_mode) VALUES (1, 0);
```

The `CHECK (id = 1)` invariant ensures there's always exactly one settings
row — no accidental duplicates.

---

## `src/providers/scaleway.py`

Port of `~/code/blackwhite/kaminkommander-email/src/scaleway.py`. Two send
paths:

1. **CF Workers `fetch`** (production) — uses the global `fetch` provided
   by the runtime. No heavy deps.
2. **`httpx` fallback** (local dev) — when running under `pywrangler dev`
   outside the miniflare `fetch` runtime, fall through to `httpx`.

```python
"""Scaleway Transactional Email client.

Sends emails via the Scaleway API. Supports test mode (redirect to test recipient).
Uses CF Workers global fetch with httpx fallback for local dev.
"""

import json
from dataclasses import dataclass


@dataclass
class SendResult:
    success: bool
    email_id: str | None = None
    recipient: str | None = None
    error: str | None = None


def _build_payload(
    project_id: str,
    from_email: str,
    from_name: str,
    to_email: str,
    subject: str,
    body: str,
    reply_to: str | None = None,
) -> dict:
    """Build the Scaleway API request payload."""
    payload: dict = {
        "from": {"email": from_email, "name": from_name},
        "to": [{"email": to_email}],
        "subject": subject,
        "text": body,
        "project_id": project_id,
    }
    if reply_to:
        payload["additional_headers"] = [{"key": "Reply-To", "value": reply_to}]
    return payload


async def _send_via_global_fetch(api_url: str, secret_key: str, payload: dict) -> dict:
    """Send via CF Workers global fetch (production path)."""
    from js import Headers, Object, fetch
    from pyodide.ffi import to_js

    headers = Headers.new()
    headers.set("Content-Type", "application/json")
    headers.set("X-Auth-Token", secret_key)

    init = to_js(
        {"method": "POST", "headers": headers, "body": json.dumps(payload)},
        dict_converter=Object.fromEntries,
    )

    response = await fetch(api_url, init)
    result_text = await response.text()

    if not response.ok:
        raise RuntimeError(f"Scaleway API error ({response.status}): {result_text}")

    return json.loads(result_text)


async def _send_via_httpx(api_url: str, secret_key: str, payload: dict) -> dict:
    """Send via httpx (local dev fallback)."""
    import httpx

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            api_url,
            json=payload,
            headers={
                "X-Auth-Token": secret_key,
                "Content-Type": "application/json",
            },
        )
        if response.status_code >= 400:
            raise RuntimeError(
                f"Scaleway API error ({response.status_code}): {response.text}"
            )
        return response.json()


async def send_email(
    env,
    to_email: str,
    subject: str,
    body: str,
    *,
    test_mode: bool = False,
    test_recipient: str | None = None,
) -> SendResult:
    """Send an email via Scaleway Transactional Email API.

    Reads Scaleway credentials from CF Workers env. Test mode (redirect to
    test recipient) is controlled by explicit parameters rather than env
    vars, so it can be toggled from the DB without redeployment.
    """
    project_id = getattr(env, "SCALEWAY_PROJECT_ID", None)
    secret_key = getattr(env, "SCALEWAY_SECRET_KEY", None)
    region = getattr(env, "SCALEWAY_REGION", "fr-par")
    from_email = getattr(env, "EMAIL_FROM", "noreply@example.com")
    from_name = getattr(env, "EMAIL_FROM_NAME", "")
    reply_to = getattr(env, "EMAIL_REPLY_TO", None)

    if not project_id or not secret_key:
        return SendResult(
            success=False,
            error="Scaleway not configured (PROJECT_ID or SECRET_KEY missing)",
        )

    actual_recipient = to_email
    if test_mode:
        if not test_recipient:
            return SendResult(
                success=False,
                error="test_mode is on but test_recipient is not set",
            )
        actual_recipient = test_recipient

    api_url = f"https://api.scaleway.com/transactional-email/v1alpha1/regions/{region}/emails"

    payload = _build_payload(
        project_id=project_id,
        from_email=from_email,
        from_name=from_name,
        to_email=actual_recipient,
        subject=subject,
        body=body,
        reply_to=reply_to,
    )

    # Try Workers runtime fetch first; fall back to httpx for local dev.
    try:
        result = await _send_via_global_fetch(api_url, secret_key, payload)
    except RuntimeError as e:
        # API returned an error — don't fall through, surface it.
        return SendResult(success=False, recipient=actual_recipient, error=str(e))
    except Exception:
        # No `js.fetch` — we're not in the Workers runtime. Use httpx.
        try:
            result = await _send_via_httpx(api_url, secret_key, payload)
        except Exception as e:
            return SendResult(success=False, recipient=actual_recipient, error=str(e))

    return SendResult(
        success=True,
        email_id=result.get("id"),
        recipient=actual_recipient,
    )
```

---

## Unsubscribe tokens

When a first email is queued for an address, an `email_preference` row is
created with a cryptographically-random token. The token is included in the
email footer as:

```
https://<UNSUBSCRIBE_BASE_URL>/unsubscribe/<token>
```

The `/unsubscribe/<token>` endpoint flips `unsubscribed = 1` and records
`unsubscribed_at`. Every `send_email` check path must filter by
`unsubscribed = 0` before queuing.

```python
# src/routes/unsubscribe.py (sketch)
import secrets
from fastapi import APIRouter, Depends
from sqlalchemy import text

from db import get_engine

router = APIRouter()


@router.get("/unsubscribe/{token}")
async def unsubscribe(token: str, engine=Depends(get_engine)):
    async with engine.begin() as conn:
        result = await conn.execute(
            text(
                "UPDATE email_preference SET unsubscribed=1, unsubscribed_at=datetime('now') "
                "WHERE unsubscribe_token=:t RETURNING email"
            ),
            {"t": token},
        )
        row = result.fetchone()
    if not row:
        return {"ok": False, "error": "token not found"}, 404
    return {"ok": True, "email": row[0]}


def new_token() -> str:
    """Cryptographically-random, URL-safe, 32 chars."""
    return secrets.token_urlsafe(24)
```

GDPR note: `unsubscribed=1` is a hard block. Don't implement a resubscribe
endpoint — require a new opt-in flow if the user wants back.

---

## TEST_MODE toggle

The admin endpoint reads/writes `email_settings` row 1:

```python
# src/routes/settings.py
@router.get("/api/settings/email")
async def get_settings(engine=Depends(get_engine)):
    async with engine.connect() as conn:
        row = (await conn.execute(
            text("SELECT test_mode, test_recipient FROM email_settings WHERE id=1")
        )).fetchone()
    return {"test_mode": bool(row[0]), "test_recipient": row[1]}


@router.patch("/api/settings/email")
async def update_settings(body: SettingsPatch, engine=Depends(get_engine)):
    # ... UPDATE ... SET ... WHERE id = 1
    pass
```

**Every** `send_email` call reads the settings row before sending and passes
`test_mode` + `test_recipient` into the provider. Do not read them from
env vars — the whole point is DB-toggleability.

---

## Template rendering

Templates are stored in `email_template`. Render with Python's
`string.Template` for simplicity, or Jinja2 if you need conditionals. Keep
the renderer in `src/template_renderer.py`:

```python
# src/template_renderer.py
from string import Template


def render(template_body: str, variables: dict) -> str:
    return Template(template_body).safe_substitute(**variables)
```

`safe_substitute` tolerates missing variables — preferable in email where
a missing `{name}` turns into literal `{name}` rather than a 500.

---

## Rate limiting

Scaleway's transactional email has per-project limits (check your plan).
For personal projects under a few thousand sends/month, no client-side
rate limiting is needed. If you grow past that, add a token bucket in the
email Worker before the `send_email` call — don't rely on Scaleway 429s.

---

## Out of scope — see sibling skills

- **`cloudflare-baseline`** — satellite pattern rationale, service-binding
  wiring, `wrangler.jsonc` structure
- **`python-worker`** — FastAPI layout, lazy lifespan, pyodide gotchas,
  `src/worker.py` ASGI bridge
- **`secrets-1password`** — where `SCALEWAY_PROJECT_ID` / `SCALEWAY_SECRET_KEY`
  live (1Password Document `<project>-env-email-dev-vars`)
- **`ddd-layout`** — models/routes/schemas 1:1 convention this follows
- **`local-dev`** — `make start-email` / `make stop-email` Makefile targets
