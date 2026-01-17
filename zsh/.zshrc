# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

##### Core paths (macOS) #####
export DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
export ZSH="$DOTFILES/omz/ohmyzsh"
export ZSH_CUSTOM="$DOTFILES/omz/custom"
export ZSH_DISABLE_COMPFIX=true    # avoid interactive compfix prompts on fresh clones

##### Put 3rd‑party completions on fpath BEFORE compinit #####
fpath=("$ZSH_CUSTOM/plugins/zsh-completions/src" $fpath)

##### History #####
HISTFILE="$HOME/.zsh_history"
HISTSIZE=200000
SAVEHIST=200000
setopt HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS HIST_VERIFY HIST_REDUCE_BLANKS SHARE_HISTORY EXTENDED_HISTORY

##### Sensible defaults #####
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP

##### Theme: Powerlevel10k (fast) #####
ZSH_THEME="powerlevel10k/powerlevel10k"
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

##### Plugins (order matters; syntax-highlighting must be last) #####
plugins=(
  git
  fzf               # wires Ctrl-R / Ctrl-T / Alt-C if fzf is present
  z                 # simple frecency jump; zoxide below is nicer if installed
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

##### fzf defaults (use fd/rg if present) #####
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
elif command -v rg >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git"'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# Previews with bat/eza if available
if command -v bat >/dev/null 2>&1; then
  export FZF_CTRL_T_OPTS='--preview "bat --style=plain --paging=never --color=always {} || cat {}"'
  export FZF_ALT_C_OPTS='--preview "eza -lah --color=always {} || ls -la {}"'
fi

##### zoxide (optional but great) #####
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

##### jenv (Java version management) #####
if command -v jenv >/dev/null 2>&1; then
  export PATH="$HOME/.jenv/bin:$PATH"
  eval "$(jenv init -)"
fi

##### Completion UX tweaks #####
autoload -Uz compinit
COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump"
compinit -d "$COMPDUMP" -C

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*'
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{blue}-- %d --%f'

##### Keybindings #####
bindkey -e            # Emacs mode (use `bindkey -v` for vi mode)

##### Aliases & QoL #####
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
else
  alias ls='ls -GFh'
fi
alias ll='ls -la'
command -v bat >/dev/null 2>&1 && alias cat='bat -p'
command -v rg  >/dev/null 2>&1 && alias grep='rg'
alias ..='cd ..'
alias ...='cd ../..'

# Java version switching aliases (jenv)
if command -v jenv >/dev/null 2>&1; then
  alias j17='jenv global 17'
  alias j21='jenv global 21'
  alias j24='jenv global 24'
  alias jversions='jenv versions'
  alias jlocal='jenv local'
  alias jglobal='jenv global'
  alias jwhich='jenv which java'
fi

: ${EDITOR:=hx}

##### Terminal IDE workflow #####
# Quick file find and open
ff() { ${EDITOR} "$(fzf)"; }

# Interactive grep with preview
fgr() {
  rg --line-number --color=always "$@" | \
    fzf --ansi --delimiter ':' \
        --preview 'bat --color=always --highlight-line {2} {1}' \
        --preview-window '+{2}-5' | \
    cut -d':' -f1-2 | \
    xargs -I{} sh -c 'hx "$(echo {} | cut -d: -f1):$(echo {} | cut -d: -f2)"'
}

# Zellij workflow aliases
if command -v zellij >/dev/null 2>&1; then
  alias zj='zellij'
  alias zja='zellij attach'
  alias zjl='zellij list-sessions'
  # Start Claude Code dev session
  alias dev='zellij --layout claude-dev'
  alias devmin='zellij --layout minimal'
fi

# Lazygit alias
command -v lazygit >/dev/null 2>&1 && alias lg='lazygit'

# Yazi - change directory on exit
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# Tree view alias using eza
alias tree='eza --tree --level=3 --icons'

# Ensure brew env (useful in login shells)
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
export PATH="$HOME/.local/bin:$PATH"

# Machine-specific environment variables (not tracked in git)
# Create ~/.zshrc.local to add variables that should only apply to this machine
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
