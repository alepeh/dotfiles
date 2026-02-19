## Project Context
- **Stack**: Shell (Zsh/Bash), Makefile, Hugo (site), Python (MCP servers)
- **Type**: macOS dotfiles — terminal IDE config (Zellij, Helix, yazi, lazygit, Claude Code MCP)
- **Install**: `make install` (symlinks configs, installs Homebrew packages)
- **Update**: `make update` (Homebrew bundle + git submodules)
- **Health check**: `make doctor` / `make doctor-mcp`
- **Hugo site**: `make site-serve` / `make site-build`

Run `make help` for all available commands.

## Key Directories
- `zsh/` — .zshrc, .zshenv, shell config
- `helix/` — Helix editor config + languages
- `zellij/` — Zellij multiplexer layouts
- `claude-code/` — Global CLAUDE.md, MCP settings, slash commands
- `mcp-servers/` — Custom MCP server implementations
- `mcp-wrappers/` — Wrapper scripts for MCP servers (load secrets from ~/.env.mcp)
- `scripts/` — install.sh, update-plugins.sh
- `site/` — Hugo site (personal blog/changelog)
- `omz/` — Oh My Zsh + plugins (git submodules, don't edit directly)

## Conventions
- Configs are symlinked from this repo to `~/.config/` or `~/`
- Secrets live in `~/.env.mcp` (never committed)
- MCP wrapper scripts at `~/.mcp-wrappers/` source secrets and start servers
- Git submodules for OMZ plugins — update via `make update`, not manually
