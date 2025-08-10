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

: ${EDITOR:=nvim}
ff() { ${EDITOR} "$(fzf)"; }

# Ensure brew env (useful in login shells)
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
