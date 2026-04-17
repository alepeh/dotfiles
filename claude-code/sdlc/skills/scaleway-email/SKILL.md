---
name: scaleway-email
description: Email-sending pattern for personal SDLC projects — a dedicated Worker that owns email templates and Scaleway API calls, its own D1 for settings and logs, service binding from the primary Worker, TEST_MODE flag for sandbox. Use when adding email to a project or editing the email Worker.
---

# Scaleway email

Email lives in a **dedicated satellite Worker**, never inline in the primary
service. Reference: `~/code/blackwhite/kaminkommander-email`.

## Why a satellite

- Isolates the Scaleway API credentials and rate limits
- Own D1 for templates, preferences, unsubscribe tokens, reminder logs
- Can be swapped for another provider without touching the primary service
- TEST_MODE flag lets you redirect all email to a single address during dev

## Wiring

Primary Worker's `wrangler.jsonc`:
```jsonc
"services": [
  { "binding": "EMAIL_SERVICE", "service": "<project>-email" }
]
```

Call via `env.EMAIL_SERVICE.fetch(...)` — service binding, no HTTP round-trip.

Email Worker's `wrangler.jsonc`:
```jsonc
"services": [
  { "binding": "CORE_SERVICE", "service": "<project>-core" }
]
```
A back-binding is useful for callbacks (e.g. unsubscribe resolves a user ID via core).

## Required secrets (wrangler secret put)

- `SCALEWAY_PROJECT_ID`
- `SCALEWAY_SECRET_KEY`
- `SCALEWAY_REGION` — `fr-par` by default

## Public vars

- `EMAIL_FROM` — verified sender
- `EMAIL_FROM_NAME`
- `EMAIL_REPLY_TO`
- `UNSUBSCRIBE_BASE_URL`

## TEST_MODE

Stored as a row in the email Worker's `email_settings` D1 table, not as an env
var — this lets the user toggle it from an admin endpoint without redeploying.

When `TEST_MODE=true`, every send is rerouted to `TEST_RECIPIENT` with the
original `to:` preserved in the email body/subject for verification.

## Shape of the email Worker

```
apps/email/src/
├── worker.py              # or index.ts
├── routes/
│   ├── reminders.py
│   ├── templates.py
│   ├── preferences.py
│   └── unsubscribe.py
├── providers/
│   └── scaleway.py        # the only file that calls Scaleway
└── templates/             # Handlebars or Jinja2 sources
```

Swap providers by adding a sibling to `scaleway.py` — the rest stays put.

## TODO

- [ ] Embed the Scaleway API call signature (the one part that changed between versions)
- [ ] Migration 0001 SQL for `email_settings` / `email_templates` / `reminder_logs`
- [ ] Unsubscribe token generation + verification snippets
