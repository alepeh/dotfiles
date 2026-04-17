---
name: secrets-1password
description: Secret management for personal SDLC projects using 1Password Documents API — backup-env uploads all .env files as tagged docs, restore-env pulls them back down on a fresh machine. Use whenever setting up secrets, rotating credentials, or onboarding a new machine.
---

# Secrets: 1Password Documents API

Hybrid env-file + 1Password workflow. Reference: `~/code/blackwhite/Makefile`
targets `backup-env` / `restore-env`.

## Files and their roles

| File                           | Where                   | Committed? | Purpose                                   |
|--------------------------------|-------------------------|------------|-------------------------------------------|
| `.env.secrets.example`         | repo root               | yes        | Manifest of env keys, empty values        |
| `.env.secrets`                 | repo root               | no         | Master list populated locally             |
| `.dev.vars`                    | per Worker app          | no         | Wrangler-style local secrets              |
| `.env.dev` / `.env.prod`       | per non-Worker tool     | no         | CLI tools (e.g. import scripts)           |
| Production                     | `wrangler secret put`   | —          | Actual prod secrets live in Cloudflare    |

## backup-env / restore-env

- **`make backup-env`** — upload each tracked env file to 1Password as a
  Document tagged `<project>-env-<path>` so it's discoverable later.
- **`make restore-env`** — download by tag back into the correct paths on
  a fresh machine or clone.

This lets the user delete `.env.*` files fearlessly and recover in one command.
Tag naming must be deterministic — use `<project>-env-` prefix so `op document
list --tags` returns a clean grouped set.

## 1Password vault

Use a dedicated `Development` vault. Never use the default `Private` vault — it
gets cluttered and the Documents API is slower against large vaults.

## Rotation

When rotating a secret:
1. Update the actual secret (Cloudflare, Scaleway, etc.)
2. `wrangler secret put <NAME>` in the production Worker
3. Update `.dev.vars` locally
4. Run `make backup-env` to push the new value to 1Password

Don't manually edit the 1Password doc — always edit the file and re-upload so
the local file and 1Password never drift.

## TODO

- [ ] Embed the shell commands for backup-env / restore-env (using `op` CLI)
- [ ] Document the `op signin` flow on a fresh machine
- [ ] Handle multi-file restore atomically (what if half succeeds?)
