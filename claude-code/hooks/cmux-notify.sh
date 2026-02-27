#!/bin/bash
# cmux notification hook for Claude Code
# Sends notification rings via cmux CLI when agent events fire.
# Safe to register globally — no-op outside cmux (socket guard).

# Exit immediately if not running inside cmux
[ -S /tmp/cmux.sock ] || exit 0

# Read the hook event from stdin
EVENT=$(cat)
EVENT_TYPE=$(echo "$EVENT" | jq -r '.event // "unknown"')
TOOL=$(echo "$EVENT" | jq -r '.tool_name // ""')

case "$EVENT_TYPE" in
  "Stop")
    cmux notify --title "Claude Code" --body "Session complete"
    ;;
  "PostToolUse")
    [ "$TOOL" = "Task" ] && cmux notify --title "Claude Code" --body "Agent finished"
    ;;
esac
