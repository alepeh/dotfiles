#!/usr/bin/env bash
# Apply the application-level iTerm2 settings that a Dynamic Profile cannot carry.
#
# The Dynamic Profile (iterm2/Dotfiles-MinimalP10k.json) owns everything that is
# per-profile: colors, font, cursor, bell/notification behaviour. The settings
# below live in the app preferences instead, so they need `defaults write`.
#
# What gets set:
#
#   TerminalMargin / TerminalVMargin = 4   window padding
#   TabViewType = 2                        tabs on the LEFT (vertical tab bar)
#   TabStyleWithAutomaticOption = 5        Minimal tab style
#   DimInactiveSplitPanes + 0.15           dim the split you're not in
#   HideScrollbar = true                   no scrollbar
#
# IMPORTANT: iTerm2 keeps preferences in memory and rewrites the whole plist
# when it quits, silently discarding anything written from outside. So this
# script refuses to run while iTerm2 is open.

set -euo pipefail

DOMAIN="com.googlecode.iterm2"
PROFILE_GUID="D9C0B3A2-3C7B-4B6E-9C6B-33A7A7D8A0F1"

if pgrep -xq iTerm2; then
  echo "✗ iTerm2 is running. Quit it first (⌘Q) — it would overwrite these"
  echo "  settings with its in-memory copy on exit. Then re-run:"
  echo "    make iterm-defaults"
  exit 1
fi

if [ "$(defaults read "$DOMAIN" LoadPrefsFromCustomFolder 2>/dev/null || echo 0)" = "1" ]; then
  echo "⚠ iTerm2 is configured to load preferences from a custom folder:"
  echo "    $(defaults read "$DOMAIN" PrefsCustomFolder 2>/dev/null || echo '<unknown>')"
  echo "  These writes go to the standard domain and may be ignored."
fi

echo "→ Applying iTerm2 application preferences"

# Window padding
defaults write "$DOMAIN" TerminalMargin -int 4
defaults write "$DOMAIN" TerminalVMargin -int 4

# Vertical tabs on the left
defaults write "$DOMAIN" TabViewType -int 2

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

echo "✓ Applied:"
for key in TerminalMargin TerminalVMargin TabViewType TabStyleWithAutomaticOption \
           DimInactiveSplitPanes SplitPaneDimmingAmount HideScrollbar "Default Bookmark Guid"; do
  printf '    %-30s %s\n' "$key" "$(defaults read "$DOMAIN" "$key" 2>/dev/null || echo '<unset>')"
done

echo "  Launch iTerm2 to see them."
