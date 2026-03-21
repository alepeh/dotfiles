# Launchpad — Tasks

## Phase 1: See what's happening

### 1.1 Project scaffold
- [ ] Init repo at `~/code/launchpad/` with Bun, TypeScript, Makefile
- [ ] Create directory structure: `src/`, `ui/`, `hooks/`
- [ ] Add CLAUDE.md with project context
- [ ] `make dev` target (bun --watch), `make build` target

### 1.2 HTTP server + WebSocket
- [ ] `src/server.ts` — Bun.serve() on localhost:3141
- [ ] Static file serving for `dist/` (dashboard UI)
- [ ] WebSocket upgrade at `/ws` with broadcast hub
- [ ] Health endpoint `GET /api/health`

### 1.3 Hook event receiver
- [ ] `POST /api/events` route — parse hook JSON, dispatch by `hook_event_name`
- [ ] Create `hooks/session-event.sh` — reads stdin, enriches with `cmux identify`, POSTs
- [ ] Handle SessionStart, Stop, Notification (idle_prompt), SessionEnd events
- [ ] Guard: no-op when Launchpad isn't running

### 1.4 Session state manager
- [ ] `state/sessions.ts` — in-memory map of session_id → SessionState
- [ ] Startup scan: read `~/.claude/sessions/*.json`, filter alive PIDs
- [ ] Enrich with team data from `~/.claude/teams/*/config.json`
- [ ] Enrich with team tasks from `~/.claude/tasks/{team}/*.json`
- [ ] Persist to `~/.launchpad/sessions/active/*.json` for restart recovery
- [ ] Broadcast session updates via WebSocket

### 1.5 Claude Code file watchers
- [ ] `watchers/claude.ts` — watch `~/.claude/sessions/`, `~/.claude/teams/`, `~/.claude/tasks/`
- [ ] On new/changed team config: update session enrichment
- [ ] On new/changed task file: broadcast team task progress
- [ ] On session file removed: mark session as finished

### 1.6 cmux client
- [ ] `cmux/client.ts` — typed wrapper around cmux CLI with `--json`
- [ ] `listWorkspaces()`, `listSurfaces()`, `focusPane()`, `identify()`
- [ ] `sendText()`, `sendKey()`, `newWorkspace()`, `newPane()`
- [ ] Error handling: graceful when cmux socket not available

### 1.7 Mission Control UI
- [ ] `ui/index.html` — SPA shell, dark theme CSS
- [ ] WebSocket connection + reconnect logic
- [ ] Session cards: status indicator, project, model, duration, team info
- [ ] Cards grouped by project directory (extract basename)
- [ ] Click/Enter on card → `POST /api/cmux/focus/:surface`
- [ ] `GET /api/cmux/surfaces` route + `POST /api/cmux/focus/:surface` route
- [ ] Keyboard: `j/k` navigation, `Enter` to focus
- [ ] Status bar: session count, waiting count

### 1.8 Hook installation
- [ ] `make install` target: copy hook script, merge into `~/.claude/settings.json`
- [ ] Coexist with existing cmux-notify.sh hooks
- [ ] `make uninstall` target: remove Launchpad hooks from settings

## Phase 2: Interact

### 2.1 Inbox file watcher
- [ ] `watchers/inbox.ts` — watch `~/.launchpad/inbox/` for new files
- [ ] Parse filename: `{timestamp}_{task-id}_{type}.{ext}`
- [ ] Track reviewed state via `.meta.json` sidecar files
- [ ] Broadcast `inbox:new` events via WebSocket

### 2.2 Inbox API
- [ ] `GET /api/inbox` — list artifacts (newest first, filterable by task/type)
- [ ] `GET /api/inbox/:filename` — read artifact content
- [ ] `POST /api/inbox/:filename/respond` — append response, deliver feedback

### 2.3 Feedback delivery
- [ ] Team feedback: append to `~/.claude/teams/{team}/inboxes/team-lead.json`
- [ ] Solo waiting feedback: `cmux send --surface <ref> "text"` + enter
- [ ] Safety check: verify session is still waiting before cmux send
- [ ] `POST /api/cmux/send/:surface` route with status guard

### 2.4 Inbox UI
- [ ] Inbox view: chronological artifact feed
- [ ] Artifact cards: timestamp, task, type, content preview
- [ ] Action buttons: Approve/Comment/Reject (plans), Reply/Dismiss (review-requests)
- [ ] Inline text input for comments/replies
- [ ] `j/k` navigation, `a`/`c`/`x` keyboard shortcuts
- [ ] Tab switching between Mission Control and Inbox

### 2.5 Reply from Mission Control
- [ ] Waiting session cards show [Reply] button
- [ ] Reply input opens inline on the card
- [ ] `r` keyboard shortcut to start replying

## Phase 3: Steer

### 3.1 Persistent task manager
- [ ] `state/tasks.ts` — read/write `~/.launchpad/tasks/{backlog,active,done}/*.md`
- [ ] YAML frontmatter parser (id, status, priority, project, tags)
- [ ] Create task: write new file to `backlog/`
- [ ] Move task: rename file between directories, update frontmatter status
- [ ] `GET /api/tasks`, `POST /api/tasks`, `PATCH /api/tasks/:id`

### 3.2 Task Board UI
- [ ] Kanban columns: Backlog, Active, Done
- [ ] Task cards: id, priority, project, session status indicator
- [ ] `n` new task, `m` move task, `e` edit (opens text input)
- [ ] `a` assign agent (triggers spawn flow)

### 3.3 Spawn session from task
- [ ] `POST /api/cmux/spawn` — create workspace + terminal pane + start Claude Code
- [ ] cmux workspace named after task ID
- [ ] Move task from backlog to active
- [ ] Associate new session with task
- [ ] Optional: `--worktree` flag for isolation

### 3.4 Backlog on Mission Control
- [ ] Show backlog tasks below active sessions on Mission Control
- [ ] [Assign agent] button on backlog cards
