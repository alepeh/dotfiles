#!/usr/bin/env bash
# Apply the application-level iTerm2 settings that a Dynamic Profile cannot carry.
#
# The Dynamic Profile (iterm2/Dotfiles-MinimalP10k.json) owns everything that is
# per-profile: colors, font, cursor, working directory, bell/notification
# behaviour. The settings below live in the app preferences instead, so they
# need `defaults write`.
#
# TWO KINDS OF KEYS, TWO DIFFERENT SPELLINGS
# ------------------------------------------
# iTerm2 has two preference systems and they capitalise their keys differently:
#
#   iTermPreferences (the Settings window)  -> PascalCase   e.g. LeftTabBarWidth
#   AdvancedSettingsModel (Settings>Advanced) -> camelCase   e.g. compactMinimalTabBarHeight
#
# There is no fallback: a PascalCase spelling of an advanced setting is simply
# an unknown key that iTerm2 never reads. `defaults read` will happily show it
# back to you, which makes the mistake invisible. Verify a key really exists:
#
#   strings -a /Applications/iTerm.app/Contents/MacOS/iTerm2 | grep -x '<key>'
#
# What gets set:
#
#   TerminalMargin / TerminalVMargin = 4   window padding
#   TabViewType = 2                        tabs on the LEFT (vertical tab bar)
#   TabStyleWithAutomaticOption = 5        Minimal tab style
#   LeftTabBarWidth = 380                  wide sidebar, room for real paths
#   DimInactiveSplitPanes + 0.15           dim the split you're not in
#   HideScrollbar = true                   no scrollbar
#   useSequoiaStyleTabs = true             makes the row height configurable again
#   defaultTabBarHeight = 72               tall rows: title + subtitle, no clipping
#   compactMinimalTabBarHeight = 72        same, for iTerm2 builds that use this key
#   useCustomTabBarFontSize + 18           readable sidebar text (default 11pt)
#   tabTitlesUseSmartTruncation = true     drop the common prefix, not the end
#
# The sidebar is meant to read like cmux's session list: one row per session,
# the name on the first line and the working directory on the second. The
# subtitle itself is a profile key (`Subtitle` in the Dynamic Profile).
#
# WHY THE ROW HEIGHT IS SO FIDDLY (iTerm2 3.6.x on macOS 26+)
# -----------------------------------------------------------
# For a vertical tab bar, each tab's height is the tab bar control's `height`,
# which PseudoTerminal fills in from -_desiredTabBarHeight. In 3.6.11 that
# method picks its source like this:
#
#   shouldHaveTallTabBar?  -> compactMinimalTabBarHeight
#       ...but it returns NO whenever TabViewType is left/right, so a side
#          tab bar NEVER reads compactMinimalTabBarHeight. Setting it alone
#          does nothing at all.
#   compact window type?   -> defaultTabBarHeight
#   macOS >= 26 AND NOT useSequoiaStyleTabs
#                          -> PSMTahoeTabStyle.horizontalTabBarHeight, a
#                             hardcoded 36pt that no preference can move
#   otherwise              -> defaultTabBarHeight
#
# So on Tahoe the rows were pinned at 36pt. The Minimal style draws the title
# at (centre - 6) and the subtitle one line below that, which at 14pt already
# runs ~6pt past the bottom of a 36pt row — that is the overlap between
# neighbouring tabs, and why the path line looked cut off.
#
# Turning on useSequoiaStyleTabs takes the Tahoe branch out of the picture and
# hands the height back to defaultTabBarHeight. It does not change how the tabs
# look here: with TabStyleWithAutomaticOption = 5, iTermTheme always returns
# PSMMinimalTabStyle regardless of this setting; the Tahoe style only ever
# applies to the light/dark themes.
#
# compactMinimalTabBarHeight is still written, at the same value, because
# newer iTerm2 builds do route left/right Minimal tab bars through it.
#
# IMPORTANT: iTerm2 keeps preferences in memory and rewrites the whole plist
# when it quits, silently discarding anything written from outside. So the
# writes only happen while iTerm2 is not running. When it *is* running this
# script offers to restart it from a detached helper that outlives the terminal
# it was launched from.

set -euo pipefail

DOMAIN="com.googlecode.iterm2"
PROFILE_GUID="D9C0B3A2-3C7B-4B6E-9C6B-33A7A7D8A0F1"
LOG="${TMPDIR:-/tmp}/iterm-defaults-restart.log"

# Detect iTerm2 via `ps`, not `pgrep`. pgrep matches against the argument
# vector, which macOS hides for hardened runtime apps — `pgrep -x iTerm2`
# returns nothing even with iTerm2 in the foreground, so a pgrep-based guard
# silently never fires. `ps -Ac` reports the kernel's process name instead.
# grep -x keeps the helper process `iTermServer-<version>` from matching, since
# that one outlives the app.
iterm_running() { ps -Ac -o comm= | grep -qx 'iTerm2'; }

# ---------------------------------------------------------------------------
# The writes. Only ever called with iTerm2 not running.
# ---------------------------------------------------------------------------
apply_defaults() {
  if [ "$(defaults read "$DOMAIN" LoadPrefsFromCustomFolder 2>/dev/null || echo 0)" = "1" ]; then
    echo "⚠ iTerm2 is configured to load preferences from a custom folder:"
    echo "    $(defaults read "$DOMAIN" PrefsCustomFolder 2>/dev/null || echo '<unknown>')"
    echo "  These writes go to the standard domain and may be ignored."
  fi

  echo "→ Applying iTerm2 application preferences"

  ## --- iTermPreferences (PascalCase) ---------------------------------------

  # Window padding
  defaults write "$DOMAIN" TerminalMargin -int 4
  defaults write "$DOMAIN" TerminalVMargin -int 4

  # Vertical tabs on the left
  defaults write "$DOMAIN" TabViewType -int 2

  # Sidebar width. The default 150pt truncates almost every title; 380pt fits a
  # session name at 18pt and a full ~40-character path on the subtitle line.
  # Drag the divider to change it at runtime — iTerm2 persists the new value
  # back to this same key.
  defaults write "$DOMAIN" LeftTabBarWidth -float 380

  # Minimal tab style: the tab bar takes the profile background colour, which is
  # what makes iTerm2 read as one flat surface instead of stacked chrome.
  # Other values: 0 light, 1 dark, 2/3 high contrast, 4 automatic, 6 compact.
  defaults write "$DOMAIN" TabStyleWithAutomaticOption -int 5

  # Dim inactive splits so the focused one is obvious
  defaults write "$DOMAIN" DimInactiveSplitPanes -bool true
  defaults write "$DOMAIN" SplitPaneDimmingAmount -float 0.15

  # No scrollbar
  defaults write "$DOMAIN" HideScrollbar -bool true

  # Make the dotfiles profile the default one for new windows/tabs
  defaults write "$DOMAIN" "Default Bookmark Guid" -string "$PROFILE_GUID"

  ## --- AdvancedSettingsModel (camelCase) -----------------------------------

  # Take the macOS 26 Tahoe tab bar out of the picture. Its height is a
  # hardcoded 36pt that ignores every preference; the Sequoia path reads
  # defaultTabBarHeight instead. See the header for why this is load-bearing
  # and why it does not change the Minimal look.
  defaults write "$DOMAIN" useSequoiaStyleTabs -bool true

  # Row height. This is the one that actually moves a left tab bar. 72pt holds
  # an 18pt title plus the ~14pt path subtitle with room to spare — the text
  # block is ~41pt tall and sits a little below centre, so anything under ~50
  # starts clipping into the next tab.
  defaults write "$DOMAIN" defaultTabBarHeight -float 72

  # Same value for the key newer iTerm2 builds use for left/right Minimal tab
  # bars, so the sidebar does not silently shrink back on the next upgrade.
  defaults write "$DOMAIN" compactMinimalTabBarHeight -float 72

  # Sidebar text size. iTerm2 otherwise draws tab labels at 11pt, which is
  # unreadable next to a 14pt terminal font. The subtitle is drawn at 0.8x
  # this, so 18 gives an 18pt session name over a 14pt path.
  defaults write "$DOMAIN" useCustomTabBarFontSize -bool true
  defaults write "$DOMAIN" customTabBarFontSize -float 18

  # When titles still overflow, drop what the tabs have in common rather than
  # lopping off the tail, so the part that distinguishes them survives.
  defaults write "$DOMAIN" tabTitlesUseSmartTruncation -bool true

  # Earlier versions of this script wrote these two advanced settings in
  # PascalCase, where iTerm2 never read them. Remove the dead keys so a
  # `defaults read` doesn't keep suggesting they are in effect.
  defaults delete "$DOMAIN" CompactMinimalTabBarHeight 2>/dev/null || true
  defaults delete "$DOMAIN" TabTitlesUseSmartTruncation 2>/dev/null || true

  echo "✓ Applied:"
  for key in TerminalMargin TerminalVMargin TabViewType TabStyleWithAutomaticOption \
             LeftTabBarWidth DimInactiveSplitPanes SplitPaneDimmingAmount HideScrollbar \
             "Default Bookmark Guid" useSequoiaStyleTabs defaultTabBarHeight \
             compactMinimalTabBarHeight useCustomTabBarFontSize \
             customTabBarFontSize tabTitlesUseSmartTruncation; do
    printf '    %-30s %s\n' "$key" "$(defaults read "$DOMAIN" "$key" 2>/dev/null || echo '<unset>')"
  done
}

# ---------------------------------------------------------------------------
# Detached restart helper: quit iTerm2, wait for it to actually exit (so it has
# finished rewriting its plist), write the prefs, relaunch. Runs under nohup so
# that iTerm2 quitting — which SIGHUPs the shell this was started from — does
# not take the helper with it.
# ---------------------------------------------------------------------------
restart_helper() {
  echo "→ Asking iTerm2 to quit"
  osascript -e 'tell application "iTerm" to quit' >/dev/null 2>&1 || true

  for _ in $(seq 1 60); do
    iterm_running || break
    sleep 1
  done

  if iterm_running; then
    echo "✗ iTerm2 is still running after 60s (a confirm-quit dialog?)."
    echo "  Nothing was written — the prefs would have been clobbered on quit."
    echo "  Quit iTerm2 manually, then run: make iterm2-profile"
    exit 1
  fi

  apply_defaults
  echo "→ Relaunching iTerm2"
  open -a iTerm
}

case "${1:-}" in
  --restart-helper)
    restart_helper
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if ! iterm_running; then
  apply_defaults
  echo "  Launch iTerm2 to see them."
  exit 0
fi

# iTerm2 is running. RESTART_ITERM=1 skips the prompt, 0 skips the writes.
answer="${RESTART_ITERM:-}"
if [ -z "$answer" ]; then
  echo "iTerm2 is running. Its app-level prefs can only be written while it is"
  echo "quit — it rewrites the whole plist from memory on exit otherwise."
  printf 'Quit iTerm2, apply, and relaunch it now? [y/N] '
  read -r reply </dev/tty || reply="n"
  case "$reply" in [yY]*) answer=1 ;; *) answer=0 ;; esac
fi

if [ "$answer" != "1" ]; then
  echo "Skipped app-level prefs. The Dynamic Profile is linked and already live."
  echo "Run 'make iterm2-profile' again when you're ready to restart iTerm2."
  exit 0
fi

echo "→ Restarting iTerm2 to apply (this terminal will close; log: $LOG)"
nohup "$0" --restart-helper >"$LOG" 2>&1 &
disown 2>/dev/null || true
sleep 1
