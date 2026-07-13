#!/bin/bash
# Launchpad hook for Claude Code session events.
# Reads stdin JSON and POSTs to the Launchpad service.
# Safe to register globally — no-op if Launchpad isn't running.

# Guard: exit if Launchpad is not running
curl -sf http://localhost:3141/api/health >/dev/null 2>&1 || exit 0

EVENT=$(cat)

# POST the raw event to Launchpad
echo "$EVENT" | \
  curl -sf -X POST http://localhost:3141/api/events \
    -H 'Content-Type: application/json' \
    -d @- >/dev/null 2>&1 || true
