#!/bin/bash
# Desktop notification hook for Claude Code (macOS native).
# Sends a notification when the agent needs attention or finishes.
# Replaces the former cmux-notify.sh — no terminal dependency, works anywhere.
#
# Hook events handled:
#   PostToolUse  — notify on agent (Task) completion
#   Notification — notify "needs input"
#   Stop         — notify "session complete"

command -v osascript >/dev/null 2>&1 || exit 0

EVENT=$(cat)
EVENT_TYPE=$(echo "$EVENT" | jq -r '.hook_event_name // .event // "unknown"')
TOOL=$(echo "$EVENT" | jq -r '.tool_name // ""')

notify() {
  osascript -e "display notification \"$1\" with title \"Claude Code\"" >/dev/null 2>&1
}

case "$EVENT_TYPE" in
  "PostToolUse")
    [ "$TOOL" = "Task" ] && notify "Agent finished"
    ;;
  "Notification")
    notify "Needs input"
    ;;
  "Stop")
    notify "Session complete"
    ;;
esac
