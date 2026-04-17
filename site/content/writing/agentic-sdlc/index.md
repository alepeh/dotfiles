---
title: "Agentic SDLC"
date: 2026-04-17
draft: false
tags: ["Workflow", "Tooling", "Claude Code", "Cloudflare", "DDD", "OpenSpec"]
summary: "An opt-in agent skill system that codifies how personal projects are bootstrapped and evolved — Cloudflare as infrastructure baseline, typed changes with a rule-distillation loop, architecture as living documentation."
---

Claude Code is great at individual changes. What it's *not* great at, by default, is keeping a consistent shape across many projects. Every personal side project I spin up accumulates its own conventions — its own folder layout, its own secret-management story, its own "how do I deploy this again." A year in, each one feels like a different codebase by a different person.

The fix I've landed on is an **agentic SDLC** — a bundle of Claude Code skills and slash commands that codify one set of architectural decisions across every personal project I build. One bootstrap per project, and then every subsequent piece of work is a *typed change* that goes through the same artifact lifecycle. The reference implementation is [kaminkommander](https://github.com/alepeh) (my chimney-sweep platform); the skills that generalize it live in [this dotfiles repo](https://github.com/alepeh/dotfiles) under `claude-code/sdlc/`.

This post is the overview: what it is, why it exists, how the pieces fit together, and what I get out of it.

## The two-phase model

There are exactly two kinds of operation:

- **Bootstrap** — a one-shot action that creates a new project on the baseline, or retrofits an existing one
- **Change** — every subsequent piece of work. Features, bug fixes, refactors, chores. All go through the same lifecycle.

This split matters because it shapes the whole system. Bootstrap is rare and infrastructural: it writes `wrangler.jsonc`, creates `architecture/`, wires the Makefile, writes a `.sdlc.yaml` config. Changes are common and typed: they get classified, scaffolded with artifacts, implemented, verified, and archived with a rule-distillation step.

Two commands for bootstrap:

```
/sdlc:bootstrap <name>     # new project from scratch
/sdlc:import <path>        # retrofit an existing project
```

Seven commands for changes:

```
/sdlc:new <name>           # classify + scaffold the first artifact
/sdlc:ff <name>            # fast-forward: classify + all artifacts at once
/sdlc:continue             # next artifact in sequence for an in-flight change
/sdlc:apply                # implement tasks; prompts for rule distillation at the end
/sdlc:verify               # 4-dimensional verification report
/sdlc:archive              # distill rules, sync delta specs, move to archive/
/sdlc:explore              # thinking partner mode — no code writes
```

If that feels like too many: it's not. Most days I use three of them (`/sdlc:new`, `/sdlc:apply`, `/sdlc:archive`) and the rest are there for the edge cases (starting fresh each morning, verifying before archive, exploring an uncertain change before committing).

## Pinned opinions

The bootstrap encodes a pile of decisions that I don't want to re-litigate for every new project. They're opinions, not gospel — but they're pinned, and drift from them is visible because any deviation needs an ADR.

| Concern            | Pinned choice                                                 |
|--------------------|---------------------------------------------------------------|
| Infrastructure     | Cloudflare — Workers, Pages, D1, R2, Durable Objects          |
| TS Workers         | [Hono](https://hono.dev/) for routing, Zod for validation     |
| Python Workers     | FastAPI + `sqlalchemy-cloudflare-d1`, uv for deps             |
| SPAs               | Vanilla JS + Vite (no framework)                              |
| Heavy jobs         | Container via Durable Object pool                             |
| Database           | D1 per service — satellites get their own                     |
| Storage            | R2                                                            |
| Worker ↔ Worker    | Service bindings, never HTTP                                  |
| Email              | Dedicated Scaleway Worker with a TEST_MODE flag               |
| Secrets            | `.dev.vars` locally, `wrangler secret put` in prod, 1Password as SoT |
| Docs               | `architecture/{domain-model,guidelines,rules,decisions/}.md` + OpenSpec |
| CI/CD              | GitHub Actions: typecheck + test. Deploys are manual via `make deploy`. |
| Local dev          | Makefile with `start_service` / `stop_service` macros, D1 snapshot/restore |

Each of these is its own skill under `claude-code/sdlc/skills/`. When Claude Code scaffolds a new Worker, it reads the `hono-worker` skill for `tsconfig.json`, the `cloudflare-baseline` skill for `wrangler.jsonc`, the `local-dev` skill for the Makefile, and so on. No one file owns all the opinions — each skill owns its concern, cross-referenced at the handoff.

The skills are opt-in. They live in my dotfiles repo and install via `make install-sdlc` (not the normal `make install`). They're explicitly *not* enabled on my work machine — on that machine, Claude Code should behave like it always has.

## A walkthrough: greenfield to archived change

Here's what actually happens when I start a new project and make the first change to it.

### Monday morning, new idea

I want to build a tiny email-summarization service. Runs on Cloudflare, takes an email, produces a one-paragraph summary via an LLM.

```
/sdlc:bootstrap email-summarizer
```

Claude asks me a handful of questions (AskUserQuestion, all at once):
- Runtime? → `worker-python` (I want FastAPI, `sqlalchemy-cloudflare-d1`)
- D1? → yes
- Email sending? → no (this service *receives* summaries via webhook; it doesn't send)
- Custom domain? → `summarize.pehm.co.at`

Ten steps later, I have a monorepo at `~/code/email-summarizer/` with:

- A `Makefile` that knows `make dev`, `make test`, `make deploy`, `make snapshot-db`, `make backup-env`
- `apps/core/` with a FastAPI Python Worker scaffolded from the `python-worker` skill
- `architecture/` with domain-model / guidelines / rules / decisions / acceptance placeholders
- `.sdlc.yaml` at the root
- `openspec/` initialized
- An Obsidian note created in my vault at `notes/Email Summarizer.md` linking to the GitHub repo
- An initial commit on `main`

Total wall-clock time: maybe three minutes, most of it spent answering the questions.

### Tuesday: first real change

I want to add the summarization endpoint.

```
/sdlc:ff summarize-endpoint
```

`ff` is "fast-forward" — Claude classifies this as a `feature`, asks me what feature group this belongs to (none yet, so I skip the AC gate), generates all four artifacts: `proposal.md`, `specs/summarize/spec.md`, `design.md`, `tasks.md`. The `design.md` includes a domain-impact checklist — is there a new entity? a new relationship? Claude runs through the 9 questions and concludes "additive" (introduces a `Summary` entity). The first task in `tasks.md` is automatically "Update `architecture/domain-model.md` with the Summary aggregate."

I read the artifacts, tweak the scope, then:

```
/sdlc:apply
```

Claude loops through the tasks. It marks each `[ ]` → `[x]` as it finishes. When all tasks are done, it asks:

> Did this implementation reveal anything that should become a rule? Look for mistakes narrowly avoided, patterns that worked well, assumptions that broke, debt taken on deliberately.

I noticed that the naive LLM call blew past Workers' CPU budget, and I had to move it to a queued Durable Object. That's worth a rule:

> **R-001**: LLM calls must be queued via a Durable Object when single-request latency exceeds 30s. The Worker CPU budget is hard, and bulk inference blocks the request handler.

Claude appends it to `architecture/rules.md` and records `R-001` in the change's `meta.yaml`.

### Wednesday: verify and archive

```
/sdlc:verify
```

Four-dimensional report: completeness (7/7 tasks, 2/2 spec requirements covered), correctness (implementation matches spec), acceptance criteria (skipped — no feature groups configured), coherence (domain model updated, follows guidelines). Verdict: ready.

```
/sdlc:archive
```

Claude runs the distillation prompt one more time (anything I missed Tuesday?), merges the delta spec at `changes/summarize-endpoint/specs/summarize/spec.md` into the main spec at `openspec/specs/summarize/spec.md`, sets `completed: 2026-04-21` in `meta.yaml`, and moves the change to `changes/archive/2026-04-21-summarize-endpoint/`.

The project is now one real feature richer, with:
- Implementation merged on `main`
- Main spec updated with the new capability
- `architecture/rules.md` has R-001
- `architecture/domain-model.md` has the Summary aggregate
- The change's trail is preserved in the archive

The next change starts with all of that as context.

## Why *typed* changes

The 8 change types (`feature`, `enhancement`, `bugfix`, `ux`, `refactor`, `infra`, `data`, `docs`) exist because they require different artifacts.

- A **feature** needs a proposal (why), specs (what — delta format with ADDED/MODIFIED/REMOVED/RENAMED requirements), a design (how), and tasks
- A **bugfix** needs root-cause analysis in a `design.md` and tasks. Skipping straight to the fix without root-cause is how you end up fixing the symptom twice
- A **refactor** needs rationale — "this is genuinely better and here's why" — or you're just shuffling
- A **data** change needs a migration plan *and* a rollback plan

The type determines the artifact checklist. No artifacts for `docs` — a one-line README edit doesn't need a proposal. Full four artifacts for `feature` — a new capability deserves scrutiny.

This sounds bureaucratic for a personal project, and it would be if I were hand-writing the artifacts. I'm not. Claude is, using templates from the `change-protocol` skill. My cost is reading the draft and saying "yes, but tighten the risks section." The benefit is that six months from now, I can read `changes/archive/2026-04-21-summarize-endpoint/proposal.md` and understand what I was thinking, *why* I was thinking it, and what trade-offs I considered.

## The rule-distillation loop

The single most valuable part of the system is the distillation prompt. It fires twice per change: once at the end of `/sdlc:apply` and once at the start of `/sdlc:archive`. Both times it asks the same four questions:

- Mistakes avoided — what almost went wrong?
- Patterns discovered — what approach worked well?
- Assumptions broken — what did we learn about the domain?
- Debt identified — what shortcut was taken deliberately?

Most of the time I answer "none" and move on. But maybe one change in four produces a real rule — something I want to remember and apply to every subsequent change. Those rules go into `architecture/rules.md` with a stable `R-NNN` ID, a source (the change that produced it), a one-sentence rule, and a one-sentence "why."

Over a year, `rules.md` becomes the accumulated wisdom of the project. It's what I'd hand to a contributor on day one. It's also what `/sdlc:apply` reads *before* implementing any new task — so past lessons propagate forward automatically.

This is the part that I can't imagine doing manually. I'd forget. With Claude asking every single time, I catch roughly 3× as many rules as I would on my own.

## Architecture as living documentation

`architecture/domain-model.md` is the second file that gets updated every change — but only when the change has domain impact. The 9-item checklist in the `change-protocol` skill makes the determination:

- New entity or aggregate?
- New or changed enum values?
- New relationship between entities?
- Changed invariant?
- New bounded-context interaction?
- Schema change?
- New migration?
- Sync-behavior change?
- Status-workflow change?

If any of these answers "yes," the impact is `additive` (new concepts) or `breaking` (existing concepts changed). In both cases, the **first task** in `tasks.md` is always to update `domain-model.md`. So the doc is updated *before* the implementation, not after — which means the doc is never stale by more than one in-flight change.

Kaminkommander has been run this way for a few months now, and `domain-model.md` has stayed honest. This is the first time in my life I've had living architecture documentation that actually lives.

## What this isn't

- **Not for work projects.** The whole thing is scoped to personal use. The skills are opt-in, `make install-sdlc` is a separate target, and each skill's description says "personal projects only." On my Paysafe machine, none of this is installed and Claude behaves normally.
- **Not a team-scale solution.** For one person or a pair, the manual deploy flow is fine. Past that, the CI skill has a "graduation signals" section — team > 1, multiple deploys per week, SLO anxiety — pointing to when it's time to add automated deploys.
- **Not a replacement for OpenSpec.** It builds on OpenSpec. The `openspec init` call is part of bootstrap. Delta specs follow OpenSpec grammar. The change commands wrap OpenSpec's lifecycle with stronger typing and a rule-distillation loop on top.
- **Not magical.** If I tell Claude to do something that doesn't fit the baseline — "use Postgres via Hyperdrive" — it'll do that, just without the skill scaffolding behind it. The skills exist to make the *default* path fast, not to prevent deviation.

## Where this lives

```
~/code/dotfiles/claude-code/sdlc/
├── README.md                    # contributor-facing overview
├── commands/                    # slash commands (/sdlc:bootstrap, /sdlc:new, …)
│   └── *.md
└── skills/                      # capability skills (auto-triggered)
    ├── change-protocol/         # shared knowledge base — 8 types, templates, grammar
    ├── cloudflare-baseline/     # wrangler.jsonc templates, D1/R2, service bindings
    ├── local-dev/               # Makefile macros, .dev/ layout, snapshot/restore
    ├── secrets-1password/       # backup-env / restore-env
    ├── ddd-layout/              # models/routes/schemas convention + arch docs
    ├── scaleway-email/          # satellite-Worker email pattern
    ├── python-worker/           # FastAPI + pywrangler + lazy lifespan
    ├── hono-worker/             # Hono + strict TS + Vitest
    └── cicd/                    # minimal GH Actions; manual deploys
```

Installation:

```bash
cd ~/code/dotfiles
make install-sdlc
```

The [README in the skill bundle](https://github.com/alepeh/dotfiles/tree/main/claude-code/sdlc) has the install details, the extension guide (how to flesh a stub, how to add a new skill), and a current-state table. The [kaminkommander repo](https://github.com/alepeh) — where all of these patterns originated — is the reference implementation.

## What I'd do differently next time

- **Start with the change protocol, not the infra baseline.** The bootstrap skill came first because it felt foundational, but the change protocol is where the daily value is. If I were starting over, I'd get `/sdlc:new` / `/sdlc:apply` / `/sdlc:archive` working against existing projects first, then add bootstrap.
- **Write the skills TODO-first.** I wrote a few stubs early and they sat as stubs for longer than I'd planned because the system technically worked without them. Next time I'd either write them fully up front or skip them entirely until the first real gap forced the issue.
- **Install on day one, iterate from feedback.** I hand-wrote a lot of the skills based on memory of how I work, then installed later. The gaps between intended and actual behavior were bigger than I expected.

All three are mistakes in the "premature polish" family. The system works; these are notes for the next one.

---

The whole setup is an experiment in whether you can make agentic coding *consistent* across many personal projects, not just fast within one. The first few weeks suggest: yes, mostly. I'll revisit this post in six months.
