## Context

Development workflows spawn background processes (wrangler dev servers, workerd runtimes, esbuild service processes) that persist after the dev session ends. Zellij sessions also accumulate in EXITED state. The Makefile already has a `##@ Cleanup` section with only a `clean` target for iTerm2 profile removal.

## Goals / Non-Goals

**Goals:**
- Provide a safe dry-run preview of what would be killed (`make cleanup-dry`)
- Provide a one-command cleanup of all orphaned dev processes (`make cleanup`)
- Show memory usage to motivate cleanup

**Non-Goals:**
- Killing active/running Zellij sessions — only EXITED ones
- Auto-scheduling cleanup (cron, launchd)

## Decisions

### 1. Two targets: dry-run and execute

`cleanup-dry` shows process counts, memory usage, and EXITED Zellij session names without side effects. `cleanup` performs the actual kills and session deletion. This follows the pattern of destructive operations having a preview mode.

### 2. Process detection via grep patterns

Each process type is identified by grep pattern against `ps aux`:
- Wrangler: `wrangler.*dev|wrangler-dist/cli.js dev`
- Workerd: `workerd serve`
- Esbuild: `esbuild.*--service`
- Pywrangler: `pywrangler dev`

Zellij EXITED sessions are detected via `zellij list-sessions | grep EXITED`.

### 3. Graceful handling of missing tools

The Zellij section guards on `command -v zellij` so the targets work even if Zellij is not installed.

## Risks / Trade-offs

- **False positive kills** → The grep patterns are specific enough to avoid matching unrelated processes. `pkill -f` uses the same patterns.
- **No confirmation prompt** → Mitigated by having the dry-run target as the recommended first step.
