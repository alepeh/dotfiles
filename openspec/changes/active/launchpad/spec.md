# Launchpad: Visual oversight for Claude Code sessions

## What it is

Launchpad is a local web dashboard that renders in cmux's WebKit browser pane. It observes running Claude Code sessions — solo or team — and gives you a single surface to see what's happening, review what agents produced, and steer work without switching between terminal panes.

It is **optional and passive by default**. You can start and stop it at any time. Claude Code sessions work exactly the same with or without Launchpad running. It never wraps, proxies, or modifies sessions — it watches from the side.

## What it is NOT

- Not a replacement for Claude Code's native task system, memory, or agent teams
- Not a project management tool (use Todoist, Linear, etc.)
- Not a knowledge base (Claude Code auto-memory already handles this)
- Not an orchestrator — Agent Teams handle coordination; Launchpad visualizes it

## Architecture

```
┌──────────────────────────────────────────────────┐
│  cmux                                            │
│  ┌──────────────────┬───────────────────────┐    │
│  │ Terminal panes    │ WebKit browser pane   │    │
│  │                   │                       │    │
│  │  Claude Code      │  Launchpad UI         │    │
│  │  sessions         │  (localhost:3141)     │    │
│  │  (solo or teams)  │                       │    │
│  └──────────────────┴───────────────────────┘    │
│         ▲                       ▲                 │
│  cmux socket API        HTTP + WebSocket          │
└─────────┼───────────────────────┼─────────────────┘
          │                       │
     ┌────┴───────────────────────┴────┐
     │        Launchpad service        │
     │                                 │
     │  HTTP API + WebSocket server    │
     │  cmux socket client             │
     │  File watchers (sessions, tasks)│
     │  Flat-file state store          │
     └────────────┬────────────────────┘
                  │
          ┌───────┴───────┐
          │ Data sources  │
          │               │
          │ ~/.claude/    │  ← sessions, teams, tasks (read-only)
          │ ~/.launchpad/ │  ← persistent tasks, inbox, config
          └───────────────┘
```

### Key principle: read from Claude Code, write to Launchpad

Launchpad **reads** Claude Code's native state directories to discover sessions, teams, and tasks. It **writes** only to its own `~/.launchpad/` directory for persistent tasks and inbox artifacts. This means Claude Code remains the source of truth for everything session-related.

## Data sources

### What Launchpad reads (owned by Claude Code)

| Path | Contains | Used for |
|------|----------|----------|
| `~/.claude/sessions/` | PID-keyed session files (`{pid: N, sessionId, cwd, startedAt}`) | Discovering active sessions |
| `~/.claude/teams/` | Team configs (`config.json` + `inboxes/*.json`) | Discovering teams and teammates |
| `~/.claude/tasks/{team}/` | Numbered task JSON files (`{id, subject, status, blocks, blockedBy}`) | Showing team task progress |
| `~/.claude/projects/` | `sessions-index.json` per project (session history, branches, summaries) | Project context, session history |
| Hook events (stdin JSON) | Session lifecycle events | Real-time status updates |

#### Claude Code file formats (reference)

**Session file** (`~/.claude/sessions/{pid}.json`):
```json
{"pid": 67648, "sessionId": "7d4c13e0-...", "cwd": "/Users/alex/code/blackwhite", "startedAt": 1774078477111}
```

**Team config** (`~/.claude/teams/{team-name}/config.json`):
```json
{
  "name": "sunny-snacking-puffin",
  "leadSessionId": "bb66d2e1-...",
  "members": [
    {"agentId": "team-lead@team-name", "name": "team-lead", "model": "claude-opus-4-6", "cwd": "/path/to/project", "tmuxPaneId": ""}
  ]
}
```

**Team inbox** (`~/.claude/teams/{team-name}/inboxes/{agent}.json`):
```json
[
  {"from": "researcher", "text": "Found the root cause...", "timestamp": "2026-03-21T14:30:00Z", "read": false}
]
```

**Team task** (`~/.claude/tasks/{team-name}/{n}.json`):
```json
{"id": "1", "subject": "Implement auth rotation", "status": "in_progress", "blocks": ["2"], "blockedBy": []}
```

**Project index** (`~/.claude/projects/-Users-alex-code-blackwhite/sessions-index.json`):
```json
{
  "entries": [
    {"sessionId": "d18e52b8-...", "firstPrompt": "fix cors", "summary": "Fixed CORS headers", "gitBranch": "fix/cors", "projectPath": "/Users/alex/code/blackwhite"}
  ]
}
```

### What Launchpad owns

```
~/.launchpad/
├── config.toml              # Launchpad configuration
├── tasks/
│   ├── backlog/
│   │   └── 2026-03-21-auth-refactor.md
│   ├── active/
│   │   └── 2026-03-20-api-pagination.md
│   └── done/
│       └── 2026-03-18-fix-cors.md
├── inbox/
│   ├── 2026-03-21T14-30_auth-refactor_plan.md
│   └── 2026-03-21T15-00_api-pagination_review-request.md
└── sessions/
    └── active/
        └── session-abc123.json   # enriched session state
```

## Session discovery and tracking

Launchpad discovers sessions through two mechanisms:

### 1. Hooks (real-time, push)

Claude Code hooks POST events to Launchpad's local endpoint. These provide real-time status updates.

```json
// ~/.claude/settings.json (or project settings)
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/launchpad-event.sh",
        "async": true
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/launchpad-event.sh",
        "async": true
      }]
    }],
    "Notification": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/launchpad-event.sh",
        "async": true
      }]
    }],
    "SessionEnd": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/launchpad-event.sh",
        "async": true
      }]
    }]
  }
}
```

The hook script reads stdin JSON, enriches it with cmux surface context, and POSTs to the Launchpad service:

```bash
#!/bin/bash
# ~/.claude/hooks/launchpad-event.sh
# Guard: no-op if Launchpad isn't running
curl -sf http://localhost:3141/api/health >/dev/null 2>&1 || exit 0

EVENT=$(cat)

# Enrich with cmux surface ID (identifies which terminal pane this session is in)
CMUX_SURFACE=""
if [ -S /tmp/cmux.sock ]; then
  CMUX_SURFACE=$(cmux --json identify 2>/dev/null | jq -r '.caller.surface_ref // empty')
fi

# Merge cmux context into the event
echo "$EVENT" | jq --arg surface "$CMUX_SURFACE" '. + {cmux_surface: $surface}' | \
  curl -sf -X POST http://localhost:3141/api/events \
    -H 'Content-Type: application/json' \
    -d @- >/dev/null 2>&1 || true
```

This solves the surface association problem: every hook event carries the `cmux_surface` ref of the terminal pane it fired from. Launchpad stores this alongside the session ID, enabling "click card → focus pane" without manual association.

**Available hook data:**
- All events: `session_id`, `hook_event_name`, `cwd` (+ `cmux_surface` from enrichment)
- SessionStart: `source`, `model`
- Notification: `message`, `title`, `notification_type` (`idle_prompt` = waiting for input)
- Stop: `last_assistant_message`
- SessionEnd: `reason`

### 2. File watching (discovery, pull)

Launchpad watches `~/.claude/teams/` and `~/.claude/tasks/` with fsnotify to discover teams and track task progress without requiring hooks. This catches teams started manually (not through Launchpad).

### Session state model

Each tracked session has a status derived from hook events:

| Status | Meaning | Source event |
|--------|---------|-------------|
| `active` | Agent is working | SessionStart, Stop (turn ended, session continues) |
| `waiting` | Waiting for human input | Notification with `idle_prompt` type |
| `finished` | Session ended | SessionEnd |

Launchpad stores enriched session state in `~/.launchpad/sessions/active/`:

```json
{
  "session_id": "abc123",
  "status": "waiting",
  "model": "claude-sonnet-4-6",
  "project_dir": "/Users/alex/code/blackwhite",
  "cmux_surface": "surface:3",
  "team_name": null,
  "started_at": "2026-03-21T14:00:00Z",
  "last_event_at": "2026-03-21T14:30:00Z",
  "last_notification": "Should I proceed with the refresh token endpoint?"
}
```

The `cmux_surface` field is populated when Launchpad spawns the session (it knows the surface ID from `cmux new-pane`), or by the user manually associating a session with a pane via the dashboard.

## Feedback delivery

The feedback mechanism depends on session type:

### Agent Teams: write to team inbox

For sessions that are part of an Agent Team, feedback is delivered by appending a message to the team lead's inbox file at `~/.claude/teams/{team-name}/inboxes/team-lead.json`.

The inbox is a JSON array. Launchpad appends:
```json
{"from": "human", "text": "Use cursor-based pagination, not offset.", "timestamp": "2026-03-21T14:35:00Z", "read": false}
```

The team lead's next mailbox check picks up unread messages automatically. This is the same mechanism teammates use to communicate — no special protocol needed.

**Lock safety:** Claude Code uses `.lock` files in task directories. Launchpad should acquire a brief advisory lock when writing to inbox files to avoid concurrent write corruption.

### Solo sessions (waiting for input): cmux send

For standalone sessions showing `idle_prompt` status (agent is waiting for the user), Launchpad uses cmux to type the feedback into the terminal:

```bash
cmux send --surface <ref> "Your feedback text here"
cmux send-key --surface <ref> enter
```

This is safe **only** when the session is waiting for input. The dashboard disables the feedback action when the session status is `active` (agent is mid-turn).

### Solo sessions (actively working): focus pane

When a solo session is actively working, there's no safe way to inject feedback. The dashboard shows a "Focus" button that switches to the terminal pane via `cmux focus-pane`, letting the human type when the agent pauses.

### Summary

| Session type | Status | Feedback action | Mechanism |
|---|---|---|---|
| Agent Team | any | Send message | Team mailbox / headless resume |
| Solo | `waiting` | Send reply | `cmux send` to terminal |
| Solo | `active` | Focus pane | `cmux focus-pane` (human types) |

## Persistent task board

Claude Code's native `TaskCreate` is session-scoped — tasks vanish when the session ends. Agent Teams tasks live in `~/.claude/tasks/{team}/` — they vanish when the team shuts down.

Launchpad's task board persists across sessions and teams. Tasks are markdown files with YAML frontmatter:

```markdown
---
id: auth-refactor
status: backlog
priority: high
created: 2026-03-21T10:00:00Z
project: /Users/alex/code/blackwhite
tags: [security, backend]
---

# Refactor authentication to use JWT rotation

## Objective

Replace static JWT with rotation-based approach.

## Acceptance criteria

- [ ] Access tokens expire after 15 minutes
- [ ] Refresh tokens expire after 7 days
- [ ] Integration tests covering rotation

## Session log

_Appended automatically when sessions work on this task._
```

### Task lifecycle

```
backlog  →  active  →  done
              ↑
              │ spawn team / assign session
              │
         Launchpad creates cmux workspace,
         starts Claude Code, optionally
         seeds Agent Team tasks from this file
```

When spawning an agent for a task, Launchpad:

1. Creates a cmux workspace named after the task ID
2. Opens a terminal pane with `claude --worktree <task-id>` (or without worktree for the main branch)
3. The session picks up task context via a `.claude/rules/launchpad.md` file or `CLAUDE.md` that references the task file path
4. Moves the task from `backlog/` to `active/`

Tasks can also be created and moved manually — they're just files in directories.

## Artifact inbox

Agents produce reviewable artifacts by writing files to `~/.launchpad/inbox/`. Launchpad watches this directory with fsnotify.

**No MCP tools needed.** Agents use their native `Write` tool:

```
Write file: ~/.launchpad/inbox/2026-03-21T14-30_auth-refactor_plan.md
```

To make this discoverable to agents, add to `~/.claude/CLAUDE.md`:

```markdown
## Launchpad Inbox

When you produce a plan, summary, or need human review, write it to
`~/.launchpad/inbox/` with filename format:
`{YYYY-MM-DDTHH-MM}_{task-id}_{type}.md`

Types: plan, diff-summary, review-request, test-results, walkthrough

For review requests, the human will append their response to the file.
Check the file for feedback before proceeding.
```

### Artifact types

| Type | Purpose | Agent writes | Human responds |
|------|---------|-------------|----------------|
| `plan.md` | Implementation plan before coding | Markdown with steps | Approve / comment / reject |
| `review-request.md` | Decision that needs human input | Question + options | Answer appended to file |
| `diff-summary.md` | Summary of changes made | Markdown | Acknowledge |
| `test-results.md` | Test output summary | Markdown | Acknowledge or fix request |

### Feedback on artifacts

When a human reviews an artifact in the dashboard:
1. Launchpad appends the response to the artifact file (the agent can re-read it)
2. Launchpad delivers the feedback to the session (via the mechanisms in "Feedback delivery" above)
3. The inbox item is marked as reviewed

## Dashboard UI

Single-page app served at `localhost:3141`, designed for cmux's WebKit pane.

### Design constraints

- Dark theme matching terminal aesthetics
- Keyboard navigable: `j/k` navigation, `Enter` to act, `Esc` to go back, `/` to search, `Cmd+K` command palette
- Information dense — optimized for split-pane widths
- Real-time via WebSocket (no polling)
- Responsive to narrow (split alongside terminals) and wide (full workspace) layouts

### Views

#### 1. Mission Control (default)

Shows all tracked sessions grouped by project.

```
┌──────────────────────────────────────────────────┐
│  Mission Control                         [⌘K]   │
│──────────────────────────────────────────────────│
│                                                   │
│  blackwhite/                                      │
│  ┌───────────────────┐  ┌──────────────────────┐ │
│  │ ● auth-refactor   │  │ ○ api-pagination     │ │
│  │   Team: 3 agents  │  │   Solo session       │ │
│  │   sonnet-4.6      │  │   opus-4.6           │ │
│  │   Working · 30m   │  │   Waiting · 2m       │ │
│  │                   │  │   "Should I use       │ │
│  │   Tasks: 2/5 done │  │    cursor-based?"     │ │
│  │   [Focus]         │  │   [Reply] [Focus]     │ │
│  └───────────────────┘  └──────────────────────┘ │
│                                                   │
│  paysafe-integration/                             │
│  ┌───────────────────┐                           │
│  │ ● payment-flow    │                           │
│  │   Solo session    │                           │
│  │   sonnet-4.6      │                           │
│  │   Working · 12m   │                           │
│  │   [Focus]         │                           │
│  └───────────────────┘                           │
│                                                   │
│  ── Backlog ─────────────────────────────────── │
│  ◻ perf-audit (blackwhite) · high                │
│  ◻ db-migration (blackwhite) · medium            │
│  [n] New task                                     │
│──────────────────────────────────────────────────│
│  5 sessions · 2 waiting · 3 inbox items          │
└──────────────────────────────────────────────────┘
```

**Session card states:**
- `●` Green — actively working
- `○` Pulsing — waiting for human input (shows last notification)
- `◻` Gray — backlog task, no session

**Keyboard:**
- `Enter` on active session → focus cmux pane
- `r` on waiting session → open reply input
- `a` on backlog task → spawn session (creates cmux workspace + Claude Code)
- `n` → create new task
- `Tab` → switch to Inbox view

#### 2. Inbox

Chronological feed of artifacts from all sessions.

```
┌──────────────────────────────────────────────────┐
│  Inbox                        Filter: [all ▾]    │
│──────────────────────────────────────────────────│
│                                                   │
│  14:30 · auth-refactor · review-request           │
│  ┌────────────────────────────────────────────┐  │
│  │ Should I use cursor-based or offset        │  │
│  │ pagination for the /api/termine endpoint?  │  │
│  │ Cursor is better for large datasets but    │  │
│  │ requires client changes.                   │  │
│  │                                            │  │
│  │ [Reply]  [Dismiss]                         │  │
│  └────────────────────────────────────────────┘  │
│                                                   │
│  14:15 · auth-refactor · plan                     │
│  ┌────────────────────────────────────────────┐  │
│  │ 1. Create TokenRotationService             │  │
│  │ 2. Add refresh endpoint                    │  │
│  │ 3. Migrate existing sessions               │  │
│  │ 4. Integration tests                       │  │
│  │                                            │  │
│  │ [Approve] [Comment] [Reject]               │  │
│  └────────────────────────────────────────────┘  │
│                                                   │
│  13:45 · payment-flow · diff-summary    ✓ Seen   │
│  ┌────────────────────────────────────────────┐  │
│  │ Added Paysafe webhook handler...           │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

**Keyboard:**
- `j/k` navigate items
- `Enter` expand/collapse
- `a` approve, `c` comment, `x` reject (on focused item)

#### 3. Task Board

Kanban view of persistent tasks.

```
┌──────────────────────────────────────────────────┐
│  Tasks                        View: [board ▾]    │
│──────────────────────────────────────────────────│
│                                                   │
│  Backlog (2)      Active (2)       Done (1)      │
│  ───────────      ───────────      ──────────    │
│  perf-audit       auth-refactor    fix-cors ✓    │
│  high · bw        ● team · 3 agt   2026-03-18   │
│                                                   │
│  db-migration     api-pagination                  │
│  med · bw         ○ solo · waiting               │
│                                                   │
│  [n] New   [e] Edit   [m] Move   [a] Assign     │
└──────────────────────────────────────────────────┘
```

## API

Minimal API — the dashboard is the primary consumer.

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/api/events` | Receive hook events (session lifecycle) |
| `GET` | `/api/sessions` | List tracked sessions |
| `GET` | `/api/tasks` | List persistent tasks |
| `POST` | `/api/tasks` | Create task |
| `PATCH` | `/api/tasks/:id` | Update task (move, edit) |
| `GET` | `/api/inbox` | List inbox artifacts |
| `POST` | `/api/inbox/:id/respond` | Submit feedback on artifact |
| `POST` | `/api/cmux/spawn` | Create workspace + start Claude Code |
| `POST` | `/api/cmux/focus/:surface` | Focus a cmux surface |
| `POST` | `/api/cmux/send/:surface` | Send text to a surface (waiting sessions only) |
| `GET` | `/api/cmux/surfaces` | List cmux surfaces via socket |
| `WS` | `/ws` | Real-time event stream for dashboard |

## Configuration

```toml
# ~/.launchpad/config.toml

[server]
port = 3141
host = "127.0.0.1"

[cmux]
socket = "/tmp/cmux.sock"

[claude_code]
# Directories where sessions can be spawned
project_roots = [
  "~/code/blackwhite",
  "~/code/paysafe"
]
# Default flags when spawning new sessions
default_flags = "--worktree"

[ui]
theme = "dark"
default_view = "mission-control"
```

## Technology

**TypeScript (Bun)** — single language for server + dashboard, native MCP SDK if needed later, same tooling as the existing MCP server in `tools/mcp-server/`.

- HTTP server: Bun's built-in `Bun.serve()`
- WebSocket: Bun native WebSocket
- File watching: Bun's `fs.watch()` or `chokidar`
- cmux integration: shell out to `cmux` CLI
- Dashboard: vanilla HTML/CSS/JS or Preact (keep it light)
- State: flat JSON/markdown files in `~/.launchpad/`

No git-as-database. Files are the database. Optionally `git init` the directory for history, but Launchpad doesn't manage commits.

## What agents need to know

Add to `~/.claude/CLAUDE.md` (only if Launchpad is in use):

```markdown
## Launchpad (optional)

If `~/.launchpad/` exists, you can write artifacts for human review:

- Write to `~/.launchpad/inbox/{ISO-timestamp}_{task-id}_{type}.md`
- Types: plan, review-request, diff-summary, test-results
- For review-requests: check the file later for appended human feedback
- Task files are in `~/.launchpad/tasks/{status}/` — you can read them for context
```

This is a suggestion, not a requirement. Agents work fine without it.

## Implementation phases

### Phase 1: See what's happening

- Launchpad service with hook event receiver
- Session discovery (hooks + file watching)
- Mission Control view with session cards
- cmux focus integration (click card → focus pane)
- WebSocket live updates

### Phase 2: Interact

- Feedback delivery (SendMessage for teams, cmux send for solo)
- Artifact inbox with fsnotify
- Inbox view with approve/comment/reject
- Reply to waiting sessions from dashboard

### Phase 3: Steer

- Persistent task board (backlog → active → done)
- Spawn sessions from task board (cmux workspace + Claude Code)
- Seed Agent Team tasks from persistent task files
- Task history (which sessions worked on what)

## Resolved questions

1. **Team feedback delivery.** ~~SendMessage or headless resume?~~ **Resolved:** Write directly to `~/.claude/teams/{team}/inboxes/team-lead.json`. This is the native inbox format — same as teammate-to-teammate communication. No CLI invocation needed.

2. **cmux surface association.** ~~How to know which pane a session is in?~~ **Resolved:** The hook script runs `cmux --json identify` to capture `caller.surface_ref` and includes it in every event POST. Works for all sessions, not just Launchpad-spawned ones.

3. **cmux data model.** Hierarchy is `window > workspace > pane > surface`. Surfaces can be `terminal` or `browser` type. Key commands: `cmux --json list-workspaces`, `cmux --json list-panes`, `cmux focus-pane --pane <ref>`, `cmux send --surface <ref> "text"`, `cmux new-workspace`, `cmux new-pane --type terminal`.

## Open questions

1. **Solo session feedback safety.** `cmux send` to a waiting session should be safe, but the `idle_prompt` notification could be stale (user typed something between notification and Launchpad send). Mitigation: use `cmux read-screen --surface <ref>` to check the last line for a prompt indicator before sending. Acceptable risk for v1.

2. **Binary artifacts.** v1 supports text artifacts only (markdown). Image support (screenshots) deferred — would need a static file server endpoint.

3. **Hook integration with existing cmux-notify.** The current `~/.claude/hooks/cmux-notify.sh` handles Notification/Stop/PostToolUse for desktop notifications. Launchpad's hook script should coexist alongside it (both registered in settings.json), not replace it. Both scripts are async and independent.
