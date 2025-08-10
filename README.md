# macOS Dotfiles — Zsh + Oh My Zsh + Powerlevel10k

Minimal, reproducible shell setup for macOS:

* **Oh My Zsh** (pinned as submodule)
* **Powerlevel10k** theme (pinned)
* **fzf** with sane defaults (`fd`/`rg`, previews via `bat`/`eza`)
* **zsh-autosuggestions**, **zsh-completions**, **zsh-syntax-highlighting** (pinned)
* **iTerm2 Dynamic Profile** (Meslo Nerd Font, dark palette)
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
* Default shell is set to `zsh` if needed.
* nvim
   ** If ~/.config/nvim exists: it’s backed up (.bak.<timestamp>), and when the repo doesn’t have nvim/ yet, your config is migrated into $DOTFILES/nvim.
   ** If neither exists: LazyVim starter is cloned into $DOTFILES/nvim.
   ** In all cases, we symlink ~/.config/nvim → $DOTFILES/nvim.

Restart your terminal or run:

```bash
exec zsh
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
