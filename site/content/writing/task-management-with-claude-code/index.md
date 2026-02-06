---
title: "Task Management with Claude Code"
date: 2026-02-06
draft: false
tags: ["Claude Code", "Workflow", "Productivity", "Tooling"]
summary: "A three-tier system for roadmap-driven development with Claude Code — using CLAUDE.md, custom slash commands, and built-in task tracking to keep multi-session projects on rails."
---

Claude Code sessions are stateless by default. You open a terminal, do some work, close it, and next time you start from scratch. That's fine for one-off tasks, but it falls apart when you're building something over days or weeks. Context drifts, priorities get forgotten, and you spend the first five minutes of every session re-explaining where you left off.

This is a system I built to fix that. It uses three Claude Code features — `CLAUDE.md` instruction files, custom slash commands, and the built-in task list — to give every session a shared understanding of what's done, what's next, and what's blocked.

## The three tiers

| Tier | What | Purpose |
|------|------|---------|
| `ROADMAP.md` | A markdown file at repo root | Single source of truth for features and priorities |
| `CLAUDE.md` | Project instructions loaded every session | Rules for how Claude interacts with the roadmap |
| Slash commands | `/init-roadmap`, `/next-task`, `/update-roadmap`, `/retrospective` | Automate the repetitive parts |

The roadmap is human-curated. Claude reads it, suggests next steps, and updates statuses — but you decide what goes in and what gets prioritized.

## ROADMAP.md

Every project gets a `ROADMAP.md` with a simple checkbox convention:

```markdown
## Progress Convention
- `[ ]` = Todo | `[-]` = In Progress | `[x]` = Completed
- Add date when starting and completing

## Current Sprint
- [-] User authentication — OAuth2 flow + session management 🏗️ 2026-02-04

## High Priority
- [ ] Rate limiting — per-user throttling on API endpoints

## Backlog
- [ ] Admin dashboard — usage stats and user management

## Recently Completed
- [x] Database schema — Postgres migrations + seed data ✅ 2026-02-03
```

Items move down as they're completed. Dates are stamped so you can see velocity at a glance. There's also a `reference/AD_HOC_TASKS.md` for small fixes that don't warrant a roadmap entry.

## CLAUDE.md rules

Claude Code loads `CLAUDE.md` at the start of every session. The project management section tells it how to behave:

```markdown
## Roadmap
- Check ROADMAP.md at the start of each session before doing significant work
- Use checkbox progression: [ ] → [-] → [x] with date stamps
- Move completed items to "Recently Completed" section
- Never commit ROADMAP.md changes in the same commit as code changes

## Task Workflow
- Use TaskCreate only for complex multi-step features with real dependencies
- For straightforward sequential work, just work naturally
```

That last rule is important. Claude Code has a built-in task list (`TaskCreate`, `TaskUpdate`, `TaskList`) that's useful for tracking complex multi-phase features where one step blocks another. But for a simple bug fix or a single-file change, formal task tracking is overhead. The instructions tell Claude to use judgment about when tracking adds value.

## The four commands

Each command is a markdown prompt file in `claude-code/commands/`. When you type `/next-task`, Claude executes the prompt as a structured workflow.

### `/init-roadmap` — bootstrap a new project

Analyzes the codebase, interviews you about priorities and tech debt, then creates `ROADMAP.md`, `reference/AD_HOC_TASKS.md`, and adds project context (stack, build/test/lint commands) to `CLAUDE.md`. One command to go from empty repo to structured workflow.

### `/next-task` — pick up the highest priority item

Reads the roadmap, identifies the top unstarted item, and asks for confirmation. Once confirmed, it marks the item in-progress with today's date and assesses complexity. Simple features get implemented directly. Complex features with genuine phase dependencies get broken into tasks with `TaskCreate` and `addBlockedBy` so Claude works through them in order.

### `/update-roadmap` — sync with git history

Cross-references `git log` with the roadmap, updates statuses for completed work, and asks about new items or priority changes. Shows a diff-style summary before writing. Commits the roadmap update separately from code — so your feature commits stay clean.

### `/retrospective` — end-of-session capture

Reviews the session's git log and task list, asks what worked and what didn't, updates the roadmap, and optionally creates a session note in Obsidian via MCP. Summarizes the top priorities for next time so you can pick up cleanly.

## Multi-session continuity

The system has three persistence mechanisms that work together:

- **ROADMAP.md in git** — any session reads the latest state after a pull
- **Claude's task list** — persists in `~/.claude/tasks/`. Set `CLAUDE_CODE_TASK_LIST_ID=<project-name>` in your shell and multiple concurrent sessions share the same list
- **Session history** — `claude --continue` picks up the last session's context, `claude --resume` lets you choose from past sessions

For parallel feature work, git worktrees let each Claude session operate in its own directory on its own branch without conflicts.

## Day-to-day cadence

```
Start:    claude --continue → CLAUDE.md loads → Claude checks ROADMAP.md
Work:     /next-task → implement → commit → test
Wrap up:  /update-roadmap → /retrospective
```

The system is designed to be low-friction. Skip steps when they don't add value. Not every session needs a retrospective. Not every feature needs formal task tracking. The structure is there for when you need it, invisible when you don't.

## Setting it up

The commands and workflow files live in my [dotfiles repo](https://github.com/alepeh/dotfiles/tree/main/claude-code). To add them to your own project:

1. Copy the `commands/` directory into your project's Claude Code configuration
2. Add the roadmap and task workflow rules to your `CLAUDE.md`
3. Run `/init-roadmap` to bootstrap the roadmap for your project

Or just steal the parts that make sense for your workflow. The whole thing is markdown — there's nothing to install.
