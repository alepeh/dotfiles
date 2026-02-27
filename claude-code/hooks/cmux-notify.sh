#!/bin/bash
# cmux notification + sidebar hook for Claude Code
# Updates sidebar status/progress and sends notification rings via cmux CLI.
# Safe to register globally — no-op outside cmux (socket guard).
#
# Hook events handled:
#   PreToolUse   — set agent "working", show tool name + progress
#   PostToolUse  — clear tool/progress, notify on agent (Task) completion
#   Notification — set agent "waiting", clear tool/progress
#   Stop         — set agent "done", clear everything, notify

# Exit immediately if not running inside cmux
[ -S /tmp/cmux.sock ] || exit 0

# Read the hook event from stdin
EVENT=$(cat)
EVENT_TYPE=$(echo "$EVENT" | jq -r '.hook_event_name // .event // "unknown"')
TOOL=$(echo "$EVENT" | jq -r '.tool_name // ""')

# Catppuccin Mocha palette
BLUE="#89b4fa"    # working
MAUVE="#cba6f7"   # tool label
YELLOW="#f9e2af"  # waiting for input
GREEN="#a6e3a1"   # done

case "$EVENT_TYPE" in
  "PreToolUse")
    cmux set-status agent "working" --color "$BLUE"
    cmux set-status tool "$TOOL" --color "$MAUVE"
    cmux set-progress 0.5 --label "$TOOL"
    ;;
  "PostToolUse")
    cmux clear-status tool
    cmux clear-progress
    [ "$TOOL" = "Task" ] && cmux notify --title "Claude Code" --body "Agent finished"
    ;;
  "Notification")
    cmux set-status agent "waiting" --color "$YELLOW"
    cmux clear-status tool
    cmux clear-progress
    cmux notify --title "Claude Code" --body "Needs input"
    ;;
  "Stop")
    cmux set-status agent "done" --color "$GREEN"
    cmux clear-status tool
    cmux clear-progress
    cmux notify --title "Claude Code" --body "Session complete"
    ;;
esac
