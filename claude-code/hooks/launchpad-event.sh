#!/bin/bash
# Launchpad hook for Claude Code session events.
# Reads stdin JSON, enriches with cmux surface ID, POSTs to Launchpad service.
# Safe to register globally — no-op if Launchpad isn't running.

# Guard: exit if Launchpad is not running
curl -sf http://localhost:3141/api/health >/dev/null 2>&1 || exit 0

EVENT=$(cat)

# Enrich with cmux surface ID (identifies which terminal pane this session is in)
CMUX_SURFACE=""
if [ -S /tmp/cmux.sock ]; then
  CMUX_SURFACE=$(cmux --json identify 2>/dev/null | jq -r '.caller.surface_ref // empty')
fi

# Merge cmux context and POST to Launchpad
echo "$EVENT" | jq --arg surface "$CMUX_SURFACE" '. + {cmux_surface: $surface}' | \
  curl -sf -X POST http://localhost:3141/api/events \
    -H 'Content-Type: application/json' \
    -d @- >/dev/null 2>&1 || true
