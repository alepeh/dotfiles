#!/usr/bin/env bash
# Apply the repo's shared Claude Code settings into ~/.claude/settings.json.
#
# ~/.claude/settings.json is deliberately untracked and NOT a symlink, because
# Claude Code rewrites it on every session (model, theme, tui, voice,
# enabledPlugins). Symlinking it into the repo left the working tree
# permanently dirty and made plain `git pull` refuse to run.
#
# claude-code/settings.base.json holds only the config worth sharing across
# machines — env, permissions, hooks — and this script merges it over whatever
# is already on the machine. Keys absent from the base file are left alone, so
# app-managed preferences survive. `hooks` is replaced wholesale rather than
# deep-merged, so dropping a hook event from the base file also drops it here.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$REPO_DIR/claude-code/settings.base.json"
DST="$HOME/.claude/settings.json"

command -v jq >/dev/null || { echo "Error: jq not found — run: brew install jq" >&2; exit 1; }
[ -f "$BASE" ] || { echo "Error: $BASE missing" >&2; exit 1; }

mkdir -p "$(dirname "$DST")"

# Migrate machines still on the old symlink layout: keep the live content as
# the machine-local starting point, then replace the link with a real file.
if [ -L "$DST" ]; then
    echo "→ Converting ~/.claude/settings.json from symlink to a local file"
    link_target="$(readlink "$DST")"
    rm -f "$DST"
    if [ -f "$link_target" ]; then
        cp "$link_target" "$DST"
    fi
fi

[ -f "$DST" ] || echo '{}' > "$DST"

if ! jq -e . "$DST" >/dev/null 2>&1; then
    backup="${DST}.bak.$(date +"%Y%m%d_%H%M%S")"
    echo "⚠  $DST is not valid JSON — backing up to $backup and starting fresh" >&2
    mv "$DST" "$backup"
    echo '{}' > "$DST"
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
jq -n --slurpfile local "$DST" --slurpfile base "$BASE" '
    ($local[0] // {}) as $l
    | ($base[0] // {}) as $b
    | ($l * $b)
    | if $b | has("hooks") then .hooks = $b.hooks else . end
' > "$tmp"
mv "$tmp" "$DST"
trap - EXIT

echo "✓ Applied claude-code/settings.base.json → $DST"
echo "  Machine-local keys (model, theme, tui, voice, enabledPlugins) preserved"
