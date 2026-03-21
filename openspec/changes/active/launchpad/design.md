# Launchpad — Design

## Project layout

```
~/code/launchpad/              # standalone repo
├── src/
│   ├── server.ts              # Bun.serve() — HTTP + WebSocket
│   ├── routes/
│   │   ├── events.ts          # POST /api/events (hook receiver)
│   │   ├── sessions.ts        # GET /api/sessions
│   │   ├── tasks.ts           # CRUD /api/tasks
│   │   ├── inbox.ts           # GET /api/inbox, POST respond
│   │   └── cmux.ts            # spawn, focus, send, surfaces
│   ├── state/
│   │   ├── sessions.ts        # session state manager
│   │   ├── tasks.ts           # persistent task CRUD (file-backed)
│   │   └── inbox.ts           # inbox artifact manager
│   ├── watchers/
│   │   ├── claude.ts          # watch ~/.claude/{sessions,teams,tasks}
│   │   └── inbox.ts           # watch ~/.launchpad/inbox/
│   ├── cmux/
│   │   └── client.ts          # cmux CLI wrapper
│   └── ws.ts                  # WebSocket broadcast hub
├── ui/
│   ├── index.html             # SPA shell
│   ├── app.ts                 # router, WS connection, keyboard handler
│   ├── views/
│   │   ├── mission-control.ts
│   │   ├── inbox.ts
│   │   └── tasks.ts
│   ├── components/
│   │   ├── session-card.ts
│   │   ├── artifact-card.ts
│   │   ├── task-card.ts
│   │   └── command-palette.ts
│   └── styles/
│       └── main.css           # dark theme, terminal-matching
├── hooks/
│   └── session-event.sh       # installed to ~/.launchpad/hooks/
├── package.json
├── tsconfig.json
├── bunfig.toml
├── Makefile
└── CLAUDE.md
```

## Key design decisions

### 1. Bun as runtime

Bun provides built-in HTTP server, native WebSocket, fast file I/O, and TypeScript execution without a build step. The entire server is `bun run src/server.ts`. No webpack, no bundler for the server.

For the UI: bundle with `Bun.build()` targeting the browser. Output a single `dist/` directory served as static files.

### 2. State architecture

Three state domains, each with a manager:

**SessionManager** (`state/sessions.ts`)
- In-memory map of `session_id → SessionState`
- Populated from hook events (push) and `~/.claude/sessions/` scanning (pull)
- Enriched with team data from `~/.claude/teams/` and cmux surface refs
- Persisted to `~/.launchpad/sessions/active/*.json` for restart recovery
- On startup: scan `~/.claude/sessions/` for PID files, check if PIDs are alive, rebuild state

**TaskManager** (`state/tasks.ts`)
- Reads/writes `~/.launchpad/tasks/{backlog,active,done}/*.md`
- Parses YAML frontmatter + markdown body
- Move = rename file between directories
- No in-memory cache needed — file reads are fast enough for the expected volume (<100 tasks)

**InboxManager** (`state/inbox.ts`)
- Watches `~/.launchpad/inbox/` with fs.watch
- Parses filename for metadata: `{timestamp}_{task-id}_{type}.{ext}`
- Reads file content on demand (markdown rendered client-side)
- Tracks reviewed/unreviewed state via a sidecar `.meta.json` file per artifact

### 3. WebSocket event protocol

Single `/ws` endpoint. All events are JSON with a `type` field:

```typescript
type WsEvent =
  | { type: "session:update"; session: SessionState }
  | { type: "session:remove"; session_id: string }
  | { type: "inbox:new"; artifact: ArtifactMeta }
  | { type: "inbox:reviewed"; filename: string }
  | { type: "task:update"; task: TaskMeta }
  | { type: "team:update"; team_name: string; tasks: TeamTask[] }
```

Dashboard connects on load, receives full state dump, then incremental updates.

### 4. cmux client

Thin wrapper around `cmux` CLI with `--json` flag. All commands are async shell-outs via `Bun.spawn()`.

```typescript
// cmux/client.ts
export async function listWorkspaces(): Promise<Workspace[]>
export async function listSurfaces(workspace?: string): Promise<Surface[]>
export async function focusPane(paneRef: string): Promise<void>
export async function sendText(surfaceRef: string, text: string): Promise<void>
export async function sendKey(surfaceRef: string, key: string): Promise<void>
export async function newWorkspace(title?: string): Promise<Workspace>
export async function newPane(opts: { type: "terminal" | "browser"; workspace?: string; direction?: string }): Promise<Surface>
export async function identify(): Promise<IdentifyResult>
```

### 5. UI framework

**Vanilla TypeScript + DOM** — no framework. Reasons:
- cmux WebKit pane is a standard browser — no framework compatibility concerns
- The UI is 3 views with ~5 components total — framework overhead isn't justified
- Keyboard handling is custom regardless of framework
- Keeps the bundle tiny (<50KB)

Use `document.createElement()` helpers, a simple client-side router (hash-based), and direct DOM manipulation. CSS custom properties for theming.

### 6. Feedback delivery implementation

```typescript
// Determine feedback mechanism for a session
function getFeedbackMethod(session: SessionState): "team-inbox" | "cmux-send" | "focus-only" {
  if (session.team_name) return "team-inbox"
  if (session.status === "waiting") return "cmux-send"
  return "focus-only"
}

// Team inbox: append to JSON array
async function sendTeamFeedback(teamName: string, message: string): Promise<void> {
  const inboxPath = `${HOME}/.claude/teams/${teamName}/inboxes/team-lead.json`
  const inbox = JSON.parse(await Bun.file(inboxPath).text())
  inbox.push({
    from: "human",
    text: message,
    timestamp: new Date().toISOString(),
    read: false
  })
  await Bun.write(inboxPath, JSON.stringify(inbox, null, 2))
}

// Solo waiting: type into terminal
async function sendSoloFeedback(surfaceRef: string, message: string): Promise<void> {
  await cmux.sendText(surfaceRef, message)
  await cmux.sendKey(surfaceRef, "enter")
}
```

### 7. Hook installation

Launchpad's `make install` target:
1. Copies `hooks/session-event.sh` to `~/.launchpad/hooks/`
2. Adds hook entries to `~/.claude/settings.json` (merging with existing hooks, not replacing)
3. Creates `~/.launchpad/` directory structure if not exists

Hook coexistence: the existing `cmux-notify.sh` stays registered. Both hooks fire async and independently on the same events.

## Data flow diagrams

### Session discovery (startup)

```
Launchpad starts
  → scan ~/.claude/sessions/*.json
  → for each: check if PID is alive (kill -0)
  → alive: create SessionState from {sessionId, cwd, startedAt}
  → scan ~/.claude/teams/*/config.json
  → for each team: enrich matching sessions with team_name, members
  → load persisted state from ~/.launchpad/sessions/active/*.json
  → merge: hook-derived state takes precedence over persisted state
  → for each session: try to find cmux surface via workspace title matching
```

### Event flow (runtime)

```
Claude Code hook fires
  → session-event.sh reads stdin JSON
  → enriches with cmux identify → cmux_surface
  → POSTs to localhost:3141/api/events
  → server updates SessionManager
  → SessionManager broadcasts via WebSocket
  → dashboard updates session card in real-time
```

### Feedback flow (team)

```
Human clicks [Reply] on dashboard
  → UI sends POST /api/inbox/:id/respond {message}
  → server reads artifact to find task_id → session → team_name
  → server appends to ~/.claude/teams/{team}/inboxes/team-lead.json
  → server appends response to artifact file
  → server broadcasts inbox:reviewed via WebSocket
  → team lead picks up message on next mailbox check
```

### Feedback flow (solo waiting)

```
Human clicks [Reply] on dashboard
  → UI sends POST /api/cmux/send/:surface {text}
  → server checks session status == "waiting"
  → server calls cmux send --surface <ref> "text"
  → server calls cmux send-key --surface <ref> enter
  → Claude Code session receives text as user input
```
