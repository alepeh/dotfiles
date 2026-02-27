## Why

The current terminal IDE stack uses iTerm2 as the terminal emulator with Zellij as the multiplexer inside it. cmux (cmux.dev) is a native macOS terminal built on Ghostty's rendering engine, purpose-built for AI agent workflows. It provides built-in tabs, splits, notification rings (when agents need attention), an embedded browser, and a socket API for automation — collapsing two layers (iTerm2 + Zellij) into one native app with first-class support for Claude Code.

## What Changes

- Install cmux via Homebrew cask (`brew install --cask cmux`) and add a `make doctor` check for it
- Create a Ghostty config (`~/.config/ghostty/config`) for terminal keybindings since cmux uses libghostty
- Add cmux workspace/layout configuration for the standard dev environment (Claude Code + Helix + shell)
- Integrate cmux notifications with Claude Code hooks so the notification ring fires on agent completion
- Adapt `claude-tui` session resume to launch in cmux instead of spawning Zellij inside iTerm2
- Keep Zellij configs intact for now (no removal) — cmux runs alongside as an alternative

## Capabilities

### New Capabilities
- `cmux-install`: Installation, Brewfile/DMG management, and doctor check for cmux
- `cmux-config`: Ghostty terminal config and cmux workspace/layout setup replacing the Zellij dev layouts
- `cmux-notifications`: Claude Code hook integration for cmux notification rings on agent events
- `cmux-session-launch`: Adapt claude-tui to launch/resume sessions in cmux instead of Zellij+iTerm2

### Modified Capabilities
_(none — existing Zellij and iTerm2 configs remain untouched as a fallback)_

## Impact

- **New files**: Ghostty config, cmux workspace config, Claude Code notification hook
- **Modified files**: `claude-tui` session launch logic (add cmux backend alongside Zellij), `Makefile` (install/doctor targets), `Brewfile` (if cmux supports cask)
- **Dependencies**: cmux app installed on macOS, Ghostty font/theme config
- **No breaking changes**: Zellij setup remains functional — cmux is additive
