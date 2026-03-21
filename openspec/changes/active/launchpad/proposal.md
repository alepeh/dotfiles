# Launchpad — Proposal

## Problem

When running multiple Claude Code sessions (solo or as Agent Teams) across projects, there's no unified surface to see what's happening. You cycle through terminal panes, miss agent notifications, and lose track of which sessions are waiting for input. Google Antigravity provides a "manager surface" for this — Claude Code has the coordination primitives (Agent Teams, hooks) but lacks the visual oversight layer.

## Solution

Launchpad: a local web dashboard that renders in cmux's WebKit browser pane. It passively observes Claude Code sessions via hooks and file watching, shows their status in a Mission Control view, collects agent-produced artifacts in an Inbox, and maintains a persistent task board that survives across sessions. It can steer work by sending feedback to teams (via their native inbox) or to solo sessions (via cmux text injection).

## Scope

**In scope (Phase 1 — v0.1):**
- Session discovery via hooks + `~/.claude/sessions/` scanning
- Mission Control dashboard with session cards (status, project, team info)
- cmux focus integration (click card → switch terminal pane)
- WebSocket-driven real-time updates
- Hook installation alongside existing cmux-notify hooks

**In scope (Phase 2 — v0.2):**
- Artifact inbox with file watching on `~/.launchpad/inbox/`
- Feedback delivery: team inbox writes + cmux send for solo sessions
- Inbox UI with approve/comment/reject actions

**In scope (Phase 3 — v0.3):**
- Persistent task board (markdown files with YAML frontmatter)
- Task board UI (kanban view)
- Spawn sessions from tasks (cmux workspace + Claude Code)

**Out of scope:**
- Knowledge base (Claude Code auto-memory handles this)
- MCP server/tools (agents use native file I/O)
- Token usage tracking (not available from hooks)
- Git-as-database
- Multi-machine sync
- Binary artifact support (screenshots)
- Todoist/GCal integration

## Technology

TypeScript + Bun. Standalone repo at `~/code/launchpad/`. Vanilla HTML/CSS/JS for the dashboard UI.

## Risks

- **cmux socket API stability:** undocumented, may change between versions
- **Claude Code internal file formats:** `~/.claude/teams/`, `~/.claude/sessions/`, `~/.claude/tasks/` are undocumented internals — could change without notice
- **WebKit pane limitations:** untested whether cmux's WebKit supports all needed APIs (WebSocket, clipboard)
- **Concurrent file access:** writing to team inbox JSON while Claude Code is also writing could corrupt data
