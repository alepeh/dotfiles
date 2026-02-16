# Project Development Workflow

A three-tier system for structured project development with Claude Code.

## Overview

| Tier | What | Purpose |
|------|------|---------|
| **ROADMAP.md** | Strategic planning file at repo root | Single source of truth for features and priorities |
| **CLAUDE.md** | Session guidance (project management rules) | Ensures Claude checks the roadmap and follows conventions |
| **Slash commands** | Workflow automation | `/init-roadmap`, `/next-task`, `/update-roadmap`, `/retrospective`, `/morning-brief`, `/evening-recap` |

## Starting a New Project

1. Run `/init-repo` to create the GitHub repo
2. Run `/init-roadmap` in the new project — creates ROADMAP.md, AD_HOC_TASKS.md, adds project context to CLAUDE.md, and creates an Obsidian project note
3. Answer the interview questions about features, tech debt, and blockers
4. The roadmap is now your single source of truth; the Obsidian note tracks status at a glance

## Starting Work on a Feature

1. Run `/next-task` — reads ROADMAP.md, suggests the highest-priority unstarted item
2. Confirm which item to work on
3. The command marks it `[-]` in progress with today's date
4. For complex features: Claude creates Tasks with dependencies via TaskCreate
5. For simple features: Claude works through it directly without formal task tracking
6. Create a feature branch following the naming convention
7. On completion, the Obsidian project note is automatically updated (current state, priorities, recent changes)

## Reprioritizing / Amending the Roadmap

- Edit ROADMAP.md directly — move items between sections, change descriptions, add new items
- Or ask Claude: "Add X to the roadmap backlog" / "Move X to high priority"
- Run `/update-roadmap` to cross-reference git history and sync statuses
- Roadmap is human-curated by design — Claude suggests, you decide

## After Completing a Feature

1. Run `/update-roadmap` — checks git log, moves completed items to "Recently Completed" with dates
2. Review the diff-style summary before writing
3. Add any new items or priority changes
4. Roadmap commit happens separately from code commits
5. Merge the feature branch via PR

## Distributing Work Across Sessions

- **Resuming context**: `claude --continue` picks up where you left off, `claude --resume` lets you choose a past session
- **Multi-session sync**: Set `CLAUDE_CODE_TASK_LIST_ID=<project-name>` in your shell — multiple Claude sessions share the same task list. When Session A completes a task, Session B sees it immediately.
- **Git worktrees**: For parallel feature work, use `git worktree add ../feature-name feature/feature-name` so each session works in its own directory
- **The roadmap bridges sessions**: Since ROADMAP.md is in git, any session reads the latest state. Tasks (in `~/.claude/tasks/`) persist across sessions too.

## End of Session

1. Run `/retrospective` — reviews git log, gathers learnings, updates roadmap notes
2. Optionally creates an Obsidian note for the session
3. Summarizes priorities for next time
4. Context is preserved in: ROADMAP.md (git), Tasks (`~/.claude/tasks/`), and session history (`--continue`)

## Chief-of-Staff Briefing Loop

A daily cadence using MCP integrations (Gmail, Calendar, Todoist, Obsidian) to stay on top of priorities.

- **Morning**: `/morning-brief` — fetches unread emails, today's calendar, overdue tasks, and yesterday's journal. Synthesises priorities and presents an approval queue for actions (Todoist tasks, email drafts).
- **Evening**: `/evening-recap` — compares morning plan vs. what happened, logs completed/open items, and offers to create carry-over tasks for tomorrow.
- **State**: Obsidian daily journal (`journals/YYYY-MM-DD.md`) is the state store. Morning Brief and Evening Recap are written as headings; re-running replaces existing sections.
- **Feedback**: Add a `## CoS Feedback` section to any journal entry — the agent reads and applies it on the next run.
- **Labels**: All agent-created Todoist tasks use the `chief-of-staff` label for tracking and dedup.

## Spec-Driven Development

Two SDD toolkits are available for structured feature work. Use spec-kit for thorough multi-phase planning, OpenSpec for lightweight fluid iteration.

### spec-kit (thorough, phase-gated)

Best for greenfield projects, complex multi-component features, and enterprise-grade specifications.

**Setup:** `specify init . --ai claude` (creates `.specify/` directory)

**Workflow:**
1. `/speckit.constitution` — Define project principles (quality, testing, UX standards)
2. `/speckit.specify` — Describe what to build and why (no tech stack yet)
3. `/speckit.clarify` — Structured Q&A to reduce ambiguity before planning
4. `/speckit.plan` — Specify tech stack and architecture, generate implementation plan
5. `/speckit.tasks` — Break plan into ordered, dependency-aware tasks
6. `/speckit.implement` — Execute all tasks in order

### OpenSpec (lightweight, fluid)

Best for brownfield features, iterative enhancements, and quick structured changes with a proposal trail.

**Setup:** `openspec init` (creates `openspec/` directory)

**Workflow:**
1. `/opsx:new <name>` — Start a new change (creates change folder with artifacts)
2. `/opsx:ff` — Fast-forward: generate proposal, specs, design, and tasks in one shot
3. `/opsx:apply` — Implement all tasks from the plan
4. `/opsx:archive` — Archive completed change and update specs

**Key difference:** OpenSpec has no rigid phase gates — update any artifact anytime, iterate freely.

### When to Use Which

| Scenario | Tool |
|----------|------|
| Greenfield project, complex multi-component feature | spec-kit |
| Brownfield feature, iterative enhancement | OpenSpec |
| Quick structured change with proposal trail | OpenSpec |
| Enterprise-grade spec with research & validation | spec-kit |
| Quick fix, small refactor, single-file change | Neither — use `/next-task` directly |

### Integration with Roadmap

Both tools complement the roadmap workflow:
1. `/next-task` picks the feature from ROADMAP.md
2. Initialize: `specify init . --ai claude` or `openspec init`
3. Plan and implement via spec-kit or OpenSpec commands
4. `/update-roadmap` marks the feature complete

## Day-to-Day Cadence

- **Start**: `claude --continue` → CLAUDE.md loads roadmap instructions → Claude checks ROADMAP.md
- **Morning brief**: `/morning-brief` → review priorities → approve actions
- **Work**: `/next-task` → implement → commit → test (use spec-kit for complex features)
- **Wrap up**: `/evening-recap` → `/update-roadmap` → `/retrospective`
- The system is designed to be low-friction — skip steps when they don't add value
