#!/bin/bash
# Attention hook for Claude Code.
#
# Goal: know when Claude Code needs you, and know WHICH tab it is in.
#
# Two layers, both optional and both fail-safe:
#
#   1. macOS desktop notification (osascript) — works in any terminal.
#   2. iTerm2-native attention:
#        RequestAttention=once  → bounce the dock icon while iTerm2 is unfocused
#        tab colour             → mark which tab is waiting on you
#      Tab colours use the Catppuccin Mocha palette so they match the profile.
#
# Hook events handled:
#   PostToolUse      — agent (Task) finished
#   Notification     — Claude needs input        → peach tab + dock bounce
#   Stop             — Claude finished its turn  → green tab + dock bounce
#   UserPromptSubmit — you're back, clear the marker
#   SessionEnd       — clear the marker

EVENT=$(cat)
EVENT_TYPE=$(echo "$EVENT" | jq -r '.hook_event_name // .event // "unknown"')
TOOL=$(echo "$EVENT" | jq -r '.tool_name // ""')

notify() {
  command -v osascript >/dev/null 2>&1 || return 0
  osascript -e "display notification \"$1\" with title \"Claude Code\"" >/dev/null 2>&1
}

# --- iTerm2 escape sequences -------------------------------------------------
# Escapes must reach the terminal, not stdout (Claude Code captures that).
#
# /dev/tty is NOT usable here: a hook is spawned without a controlling terminal
# ("ps -o tty=" reports "??"), so opening /dev/tty fails with ENXIO. The pty is
# owned by an ancestor — the `claude` process — so walk up the process tree and
# write to that device directly.

in_iterm2() {
  [ "${TERM_PROGRAM:-}" = "iTerm.app" ] || [ "${LC_TERMINAL:-}" = "iTerm2" ]
}

# Echo the path of the nearest ancestor's terminal device, or fail.
resolve_tty() {
  local pid=$$ t
  for _ in 1 2 3 4 5; do
    t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    case "$t" in
      tty*) [ -w "/dev/$t" ] && { printf '/dev/%s' "$t"; return 0; } ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -n "$pid" ] && [ "$pid" != "0" ] && [ "$pid" != "1" ] || break
  done
  return 1
}

TTY_DEV=""
in_iterm2 && TTY_DEV=$(resolve_tty || true)

iterm_seq() {
  [ -n "$TTY_DEV" ] || return 0
  printf '%b' "$1" 2>/dev/null >"$TTY_DEV" || true
}

# Bounce the dock icon once while iTerm2 is unfocused.
iterm_attention() {
  iterm_seq '\033]1337;RequestAttention=once\a'
}

# Colour this session's tab: iterm_tab_color <r> <g> <b> (0-255 each).
iterm_tab_color() {
  iterm_seq "\033]6;1;bg;red;brightness;$1\a\033]6;1;bg;green;brightness;$2\a\033]6;1;bg;blue;brightness;$3\a"
}

iterm_tab_color_reset() {
  iterm_seq '\033]6;1;bg;*;default\a'
}

case "$EVENT_TYPE" in
  "PostToolUse")
    [ "$TOOL" = "Task" ] && notify "Agent finished"
    ;;
  "Notification")
    notify "Needs input"
    iterm_tab_color 250 179 135   # Catppuccin peach #fab387
    iterm_attention
    ;;
  "Stop")
    notify "Session complete"
    iterm_tab_color 166 227 161   # Catppuccin green #a6e3a1
    iterm_attention
    ;;
  "UserPromptSubmit"|"SessionEnd")
    iterm_tab_color_reset
    ;;
esac

exit 0
