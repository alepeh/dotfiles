# macOS Dotfiles — Zsh + Oh My Zsh + Powerlevel10k

Minimal, reproducible shell setup for macOS:

* **Oh My Zsh** (pinned as submodule)
* **Powerlevel10k** theme (pinned)
* **fzf** with sane defaults (`fd`/`rg`, previews via `bat`/`eza`)
* **zsh-autosuggestions**, **zsh-completions**, **zsh-syntax-highlighting** (pinned)
* **iTerm2 Dynamic Profile** (Meslo Nerd Font, dark palette)
* **Claude MCP Servers** (Obsidian, Todoist, GitHub) with secure config
* **Homebrew Bundle** to install all dependencies
* Safe **backups** of existing Zsh configs and iTerm2 prefs

> This repo is **macOS-only** by design.

---

## Features

* **Reproducible**: All plugins and theme are git submodules pinned to commits.
* **Fast prompt**: Powerlevel10k with instant prompt enabled.
* **Better completion**: OMZ completions + `zsh-completions`, with refined matching rules.
* **Productive fuzzy find**: `fzf` with `fd`/`rg` backends and file previews via `bat`.
* **Nice defaults**: `eza`, `ripgrep`, `bat`, `zoxide` (optional) and helpful aliases.
* **iTerm2 profile**: Pre-configured font/colors; linked via Dynamic Profiles.
* **Neovim + LazyVim**: repo‑managed config at $DOTFILES/nvim, symlinked to ~/.config/nvim with automatic backups/migration.
* **Claude MCP Servers**: Secure configuration for Obsidian, Todoist, and GitHub integration.
* **Java Version Management**: jenv with JDK 17, 21, and 24 support and convenient switching aliases.

---

## Installation

### 0) Clone to a stable path

```bash
git clone git@github.com:alepeh/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

### 1) Add submodules (one-time), then commit

```bash
git submodule add https://github.com/ohmyzsh/ohmyzsh                               omz/ohmyzsh
git submodule add https://github.com/romkatv/powerlevel10k                        omz/custom/themes/powerlevel10k
git submodule add https://github.com/zsh-users/zsh-autosuggestions                omz/custom/plugins/zsh-autosuggestions
git submodule add https://github.com/zsh-users/zsh-syntax-highlighting            omz/custom/plugins/zsh-syntax-highlighting
git submodule add https://github.com/zsh-users/zsh-completions                    omz/custom/plugins/zsh-completions

git submodule update --init --recursive
git commit -m "Add OMZ + P10k + plugins as submodules"
```

### 2) Install (backs up your current Zsh files and iTerm prefs and nvim config)

**Option A: via Makefile**

```bash
make install
```

**Option B: run script directly**

```bash
./scripts/install.sh
```

What happens:

* Homebrew is installed if missing, then `brew bundle` installs CLI tools and Meslo Nerd Font.
* Submodules are initialized/updated.
* `fzf` keybindings/completions are installed.
* Existing `~/.zshrc`, `~/.zshenv`, `~/.p10k.zsh` are backed up (timestamped) and replaced with symlinks.
* iTerm2 profile JSON is linked into `~/Library/Application Support/iTerm2/DynamicProfiles/`.
* Claude MCP servers are installed and configuration is linked.
* Default shell is set to `zsh` if needed.
* nvim
   ** If ~/.config/nvim exists: it's backed up (.bak.<timestamp>), and when the repo doesn't have nvim/ yet, your config is migrated into $DOTFILES/nvim.
   ** If neither exists: LazyVim starter is cloned into $DOTFILES/nvim.
   ** In all cases, we symlink ~/.config/nvim → $DOTFILES/nvim.

Restart your terminal or run:

```bash
exec zsh
```

### MCP Server Setup

After installation, configure your API keys for Claude Desktop to access the MCP servers securely:

#### Secure Configuration Architecture

This setup uses **wrapper scripts** to keep secrets out of git while maintaining a clean, reproducible configuration:

- **`claude/claude_desktop_config.json`**: Safe to commit (contains only wrapper script paths)
- **`~/.mcp-wrappers/*.sh`**: Wrapper scripts that load secrets and start MCP servers
- **`~/.env.mcp`**: Your actual API keys (never committed, chmod 600)
- **`claude/.env.template`**: Template for required keys (committed as reference)

#### Setup Steps

1. **Create your secrets file** from the template:
   ```bash
   cp claude/.env.template ~/.env.mcp
   chmod 600 ~/.env.mcp
   ```

2. **Edit `~/.env.mcp`** and replace placeholder values with your actual API keys:
   - **OBSIDIAN_API_KEY**: Your Obsidian Local REST API key
   - **TODOIST_API_KEY**: Your Todoist API token from https://todoist.com/prefs/integrations
   - **GITHUB_PERSONAL_ACCESS_TOKEN**: GitHub PAT with `repo`, `read:org`, `read:user` scopes
     Create at: https://github.com/settings/tokens

3. **Wrapper scripts are already created** at `~/.mcp-wrappers/`:
   - `obsidian-wrapper.sh` - Loads secrets and starts mcp-obsidian
   - `todoist-wrapper.sh` - Loads secrets and starts todoist-mcp
   - `github-wrapper.sh` - Loads secrets and starts mcp-server-github

4. **Restart Claude Desktop** for changes to take effect.

#### How It Works

Each wrapper script:
1. Sources `~/.env.mcp` to load your secrets into the environment
2. Executes the actual MCP server with those variables available
3. Keeps `claude_desktop_config.json` clean and git-safe

Example wrapper script:
```bash
#!/bin/bash
# Load environment variables from secure location
if [ -f ~/.env.mcp ]; then
    source ~/.env.mcp
fi
# Start the actual MCP server
exec /opt/homebrew/bin/uvx mcp-obsidian
```

#### Verification

Test that your MCP servers are working by checking Claude Desktop's MCP server status, or test a wrapper script manually:
```bash
# Test obsidian wrapper (should connect to your Obsidian instance)
~/.mcp-wrappers/obsidian-wrapper.sh
```

#### Security Notes

- `~/.env.mcp` is protected with `chmod 600` (owner read/write only)
- Never commit `~/.env.mcp` to git (protected by `.gitignore`)
- The `claude/claude_desktop_config.json` is **safe to commit** to public repos
- Wrapper scripts can be regenerated if needed

### Java Version Management

The installation includes jenv for managing multiple JDK versions (17, 21, 24). After installation, JDKs are automatically discovered and added to jenv.

**Quick version switching:**
```bash
j17          # Switch to Java 17 globally
j21          # Switch to Java 21 globally  
j24          # Switch to Java 24 globally
```

**Project-specific Java versions:**
```bash
jlocal 17    # Set Java 17 for current directory only
echo "17" > .java-version  # Alternative: create version file
```

**Utility commands:**
```bash
jversions    # List all available Java versions
jglobal 21   # Set global Java version
jwhich       # Show current Java executable path
java -version # Verify current Java version
```

**Manual JDK installation:**
If JDKs weren't installed automatically (requires sudo), install them manually:
```bash
brew install --cask temurin@17 temurin@21 temurin
```
Then run the jenv configuration:
```bash
./scripts/install.sh  # Re-run to configure jenv with new JDKs
```

---

## Updating

Update brew packages and pinned plugins:

```bash
make update
```

* `brew bundle` ensures packages match the Brewfile.
* `scripts/update-plugins.sh` fast-forwards submodules when possible.

Dump your current brew state back to `Brewfile`:

```bash
make brew-lock
```

---

## Restore iTerm2 preferences (optional)

If you used `make install`, your current iTerm2 prefs file was backed up:

```bash
make restore-iterm
```

This copies the most recent backup to:

```
~/Library/Preferences/com.googlecode.iterm2.plist
```

Relaunch iTerm2 to apply.

---

## Extend

### Add an OMZ plugin

For built-in OMZ plugins, just add to `plugins=(...)` in `zsh/.zshrc`, e.g.:

```zsh
plugins=(git fzf z zsh-autosuggestions zsh-completions zsh-syntax-highlighting kubectl)
```

> Built-in plugins don’t need submodules.

For **third-party** plugins you want pinned, add them as submodules under `omz/custom/plugins/<name>` and then add the plugin name to `plugins=(...)`. Example:

```bash
git submodule add https://github.com/jeffreytse/zsh-vi-mode omz/custom/plugins/zsh-vi-mode
git submodule update --init --recursive
git commit -m "Add zsh-vi-mode plugin"
```

Then in `zsh/.zshrc`:

```zsh
plugins=(git fzf z zsh-autosuggestions zsh-completions zsh-vi-mode zsh-syntax-highlighting)
```

> Keep `zsh-syntax-highlighting` **last**.

### Add completions-only repos

If a repo provides only completions, add its `src` directory to `fpath` **before** `compinit` in `zsh/.zshrc`:

```zsh
fpath=("$ZSH_CUSTOM/plugins/<your-completions>/src" $fpath)
```

### Add a tool via Homebrew

Edit `Brewfile`, then:

```bash
make brew-update   # update/upgrade/cleanup
make brew-lock     # re-dump Brewfile (optional)
```

### Use zoxide instead of `z`

`zoxide` is installed via Brewfile and auto-enabled if present:

```zsh
eval "$(zoxide init zsh)"
```

You can remove `z` from OMZ plugins if you prefer `zoxide` exclusively.

### Machine-specific environment variables

For environment variables that should only apply to this machine (e.g., API keys, local paths), create `~/.zshrc.local`:

```bash
# ~/.zshrc.local
export MY_API_KEY="secret-key-for-this-machine"
export CUSTOM_PATH="/path/to/something/local"
export MACHINE_SPECIFIC_VAR="value"
```

This file is automatically sourced by `.zshrc` if it exists. Since it's gitignored and lives in your home directory (not in the dotfiles repo), it won't be committed to version control.

**Note:** After creating or modifying `~/.zshrc.local`, restart your terminal or run `exec zsh` to load the changes.

### Change prompt look

Run:

```bash
p10k configure
```

or edit `p10k/.p10k.zsh` and reload:

```bash
exec zsh
```

---

## Troubleshooting

* **Weird glyphs**: Set *MesloLGM Nerd Font* in iTerm2 → Profiles → Text.
* **“insecure completion-dependent directories”**: We set `ZSH_DISABLE_COMPFIX=true` and manage `fpath`/`compinit`; if warnings persist, check permissions on your repo path.
* **fzf bindings not active**: Ensure `brew install fzf` ran and `$(brew --prefix)/opt/fzf/install` executed (installer does this). Restart the terminal.

---

## Uninstall / Revert

* Remove symlinks:

```bash
rm ~/.zshrc ~/.zshenv ~/.p10k.zsh
```

Backups remain alongside them as `*.bak.YYYYMMDD_HHMMSS`.

* Restore iTerm2 prefs with:

```bash
make restore-iterm
```

---

## License

MIT
