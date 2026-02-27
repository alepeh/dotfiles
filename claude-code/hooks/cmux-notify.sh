#!/bin/bash
# cmux desktop notification hook for Claude Code
# Sends notification rings via cmux CLI when agent needs attention.
# Safe to register globally — no-op outside cmux (socket guard).
#
# Hook events handled:
#   PostToolUse  — notify on agent (Task) completion
#   Notification — notify "needs input"
#   Stop         — notify "session complete"

# Exit immediately if not running inside cmux
[ -S /tmp/cmux.sock ] || exit 0

EVENT=$(cat)
EVENT_TYPE=$(echo "$EVENT" | jq -r '.hook_event_name // .event // "unknown"')
TOOL=$(echo "$EVENT" | jq -r '.tool_name // ""')

case "$EVENT_TYPE" in
  "PostToolUse")
    [ "$TOOL" = "Task" ] && cmux notify --title "Claude Code" --body "Agent finished"
    ;;
  "Notification")
    cmux notify --title "Claude Code" --body "Needs input"
    ;;
  "Stop")
    cmux notify --title "Claude Code" --body "Session complete"
    ;;
esac
