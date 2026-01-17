# Claude Desktop MCP Server Configuration

This directory contains secure configuration for Claude Desktop's Model Context Protocol (MCP) servers.

## Overview

MCP servers extend Claude Desktop's capabilities by connecting it to external services like Obsidian, Todoist, and GitHub. This setup keeps your API keys secure and out of version control while maintaining a clean, reproducible configuration.

## Files

- **`claude_desktop_config.json`** - Claude Desktop configuration (safe to commit)
- **`.env.template`** - Template showing required environment variables (safe to commit)
- **`~/.env.mcp`** - Your actual secrets (NEVER commit, already in `.gitignore`)
- **`~/.mcp-wrappers/*.sh`** - Wrapper scripts that load secrets (created by install script)

## Architecture

### Why Wrapper Scripts?

Claude Desktop has known issues with environment variable handling:
- Variables defined in the `env` section strip out system variables like `PATH`
- Direct `${VAR}` references in config don't expand reliably
- GUI apps don't inherit shell environment variables

**Solution**: Wrapper scripts that:
1. Load secrets from `~/.env.mcp`
2. Start the actual MCP server with those variables available
3. Keep the config file clean and git-safe

### Security Model

```
┌─────────────────────────────────────────────────────────────┐
│ claude_desktop_config.json (git-safe, public)               │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ "command": "~/.mcp-wrappers/obsidian-wrapper.sh"        │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ ~/.mcp-wrappers/obsidian-wrapper.sh                         │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ source ~/.env.mcp                                        │ │
│ │ exec /opt/homebrew/bin/uvx mcp-obsidian                 │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ ~/.env.mcp (chmod 600, never committed)                     │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ export OBSIDIAN_API_KEY="actual-secret-key"             │ │
│ │ export TODOIST_API_KEY="actual-secret-key"              │ │
│ │ export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_..."           │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Setup

### Initial Setup (Done by install.sh)

The installation script automatically:
1. Creates `~/.mcp-wrappers/` directory
2. Generates wrapper scripts for each MCP server
3. Makes scripts executable (chmod +x)
4. Creates `~/.env.mcp` from template (chmod 600)
5. Symlinks `claude_desktop_config.json` to the correct location

### Manual Configuration Required

You must manually add your API keys:

```bash
# Edit the secrets file
vim ~/.env.mcp
# or
nano ~/.env.mcp
```

Replace these placeholders:
- `your_obsidian_api_key_here` → Your Obsidian Local REST API key
- `your_todoist_api_key_here` → Your Todoist API token
- `your_github_pat_here` → Your GitHub Personal Access Token

### Getting API Keys

**Obsidian API Key:**
1. Install the "Local REST API" plugin in Obsidian
2. Enable the plugin in Settings → Community Plugins
3. Copy the API key from plugin settings

**Todoist API Key:**
1. Go to https://todoist.com/prefs/integrations
2. Scroll to "API token" section
3. Copy your token

**GitHub Personal Access Token:**
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo`, `read:org`, `read:user`
4. Generate and copy the token

## Configured MCP Servers

### mcp-obsidian
Connects Claude to your Obsidian vault via the Local REST API plugin.

**Required variables:**
- `OBSIDIAN_API_KEY` (required)
- `OBSIDIAN_HOST` (optional, defaults to 127.0.0.1)
- `OBSIDIAN_PORT` (optional, defaults to 27124)

### todoist-mcp
Integrates Claude with your Todoist tasks.

**Required variables:**
- `TODOIST_API_KEY` (required)

**Note:** Requires the todoist-mcp server to be installed at `~/code/todoist-mcp/`

### mcp-server-github
Connects Claude to GitHub repositories, issues, and PRs.

**Required variables:**
- `GITHUB_PERSONAL_ACCESS_TOKEN` (required)

**Note:** Requires github-mcp-server to be installed at `~/go/bin/github-mcp-server`

## Troubleshooting

### MCP Servers Not Starting

1. **Check wrapper script permissions:**
   ```bash
   ls -la ~/.mcp-wrappers/
   # All .sh files should be -rwxr-xr-x
   ```

2. **Test wrapper script directly:**
   ```bash
   ~/.mcp-wrappers/obsidian-wrapper.sh
   # Should start the server or show error messages
   ```

3. **Verify secrets file exists and has correct permissions:**
   ```bash
   ls -la ~/.env.mcp
   # Should be -rw------- (chmod 600)
   ```

4. **Check secrets file has actual values (not placeholders):**
   ```bash
   cat ~/.env.mcp
   # Should NOT contain "your_*_here"
   ```

5. **Verify MCP server binaries are installed:**
   ```bash
   /opt/homebrew/bin/uvx mcp-obsidian --help
   node ~/code/todoist-mcp/build/index.js --help
   ~/go/bin/github-mcp-server --help
   ```

### Environment Variables Not Loading

If environment variables aren't being passed to the MCP server:

1. Check that wrapper script sources the env file:
   ```bash
   grep "source ~/.env.mcp" ~/.mcp-wrappers/*.sh
   ```

2. Verify the env file exports variables (not just sets them):
   ```bash
   # Correct:
   export OBSIDIAN_API_KEY="value"

   # Wrong:
   OBSIDIAN_API_KEY="value"
   ```

3. Test the wrapper script with debug output:
   ```bash
   # Add debugging to wrapper script
   #!/bin/bash
   source ~/.env.mcp
   echo "OBSIDIAN_API_KEY=$OBSIDIAN_API_KEY"  # Debug line
   exec /opt/homebrew/bin/uvx mcp-obsidian
   ```

### Claude Desktop Not Recognizing MCP Servers

1. **Restart Claude Desktop completely:**
   ```bash
   # Force quit Claude Desktop
   pkill -9 "Claude"
   # Restart it
   open -a "Claude"
   ```

2. **Check Claude Desktop config location:**
   ```bash
   # Should be symlinked from this repo
   ls -la ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

3. **Verify JSON syntax is valid:**
   ```bash
   # Use jq or python to validate
   cat claude_desktop_config.json | python -m json.tool
   ```

## Alternative Approaches

### Using launchctl (Legacy Method)

The old method used `launchctl` to set system-wide environment variables:

```bash
launchctl setenv OBSIDIAN_API_KEY "your-key"
launchctl setenv TODOIST_API_KEY "your-key"
launchctl setenv GITHUB_PERSONAL_ACCESS_TOKEN "your-token"
```

**Why we don't use this anymore:**
- Requires running script after every reboot
- Environment variables are system-wide (security concern)
- Doesn't persist across macOS updates
- Wrapper scripts are more reliable

### Direct Configuration (Insecure)

You could put secrets directly in `claude_desktop_config.json`:

```json
{
  "env": {
    "OBSIDIAN_API_KEY": "actual-secret-here"
  }
}
```

**Why we don't do this:**
- Secrets would be committed to git
- Hard to manage multiple environments
- Security risk if repo is ever public

## Maintaining Your Setup

### Adding a New MCP Server

1. Create a new wrapper script:
   ```bash
   cat > ~/.mcp-wrappers/newserver-wrapper.sh << 'EOF'
   #!/bin/bash
   if [ -f ~/.env.mcp ]; then
       source ~/.env.mcp
   fi
   exec /path/to/newserver
   EOF
   chmod +x ~/.mcp-wrappers/newserver-wrapper.sh
   ```

2. Add required variables to `~/.env.mcp`:
   ```bash
   export NEWSERVER_API_KEY="your-key"
   ```

3. Update `claude_desktop_config.json`:
   ```json
   {
     "mcpServers": {
       "newserver": {
         "command": "/Users/yourusername/.mcp-wrappers/newserver-wrapper.sh",
         "args": []
       }
     }
   }
   ```

4. Update `.env.template` for documentation:
   ```bash
   # NewServer API Key
   NEWSERVER_API_KEY=your_newserver_api_key_here
   ```

5. Restart Claude Desktop

### Rotating API Keys

1. Get new API keys from the service
2. Update `~/.env.mcp` with new values
3. Restart Claude Desktop
4. Old keys can be revoked in the service's settings

### Backing Up Your Configuration

Your dotfiles repo already contains everything except secrets:
```bash
# Back up your secrets separately (encrypted!)
# Option 1: Use 1Password, LastPass, etc.
# Option 2: Encrypt and backup
gpg -c ~/.env.mcp
# Store ~/.env.mcp.gpg in secure backup location
```

**Never commit unencrypted secrets to any repository!**

## References

- [Claude Desktop Documentation](https://docs.claude.com/en/docs/claude-desktop)
- [Model Context Protocol (MCP) Specification](https://modelcontextprotocol.io/)
- [MCP Server Environment Variables Issue](https://github.com/anthropics/claude-code/issues/1254)
- [MCP Security Best Practices](https://github.com/anthropics/claude-code/issues/2065)
