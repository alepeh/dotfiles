#!/usr/bin/env bash
# Mirror vault-resident agent skills into ~/.claude/commands.
#
# Source of truth: <vault>/agents/<name>/commands/*.md
# Each .md becomes ~/.claude/commands/<basename>.md (symlink).
#
# Idempotent: re-running fixes broken/changed links and prunes its own
# stale entries. Never touches commands that don't point into the vault
# (so hand-written commands or other dotfile-managed links are safe).

set -euo pipefail

VAULT="${HUDSON_VAULT:-$HOME/obsidian/brain}"
TARGET="$HOME/.claude/commands"

if [ ! -d "$VAULT/agents" ]; then
    echo "no agents/ under $VAULT — set HUDSON_VAULT to override" >&2
    exit 1
fi

mkdir -p "$TARGET"

# Track wanted basenames as a newline-delimited string so we stay
# compatible with macOS bash 3.2 (no associative arrays).
wanted=""

for skill_dir in "$VAULT"/agents/*/commands; do
    [ -d "$skill_dir" ] || continue
    for src in "$skill_dir"/*.md; do
        [ -f "$src" ] || continue
        name="$(basename "$src")"
        dst="$TARGET/$name"
        if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
            wanted+="${name}"$'\n'
            continue
        fi
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            rm "$dst"
        fi
        ln -s "$src" "$dst"
        echo "linked $name → $src"
        wanted+="${name}"$'\n'
    done
done

# Prune only links that previously pointed into <vault>/agents — never
# touch unrelated entries.
for existing in "$TARGET"/*.md; do
    [ -L "$existing" ] || continue
    case "$(readlink "$existing")" in
        "$VAULT/agents/"*)
            base="$(basename "$existing")"
            if ! grep -qxF "$base" <<<"$wanted"; then
                rm "$existing"
                echo "pruned stale link: $base"
            fi
            ;;
    esac
done
