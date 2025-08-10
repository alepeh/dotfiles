export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Resolve DOTFILES from this file's real path (works even if repo moves)
if [[ -z "$DOTFILES" ]]; then
  # %N = path of the file being sourced; :A absolute; :h twice = up 2 dirs (…/zsh/.zshenv -> repo root)
  local _self=${(%):-%N}
  if [[ -n "$_self" ]]; then
    export DOTFILES="${_self:A:h:h}"
  else
    export DOTFILES="$HOME/.dotfiles"   # fallback if %N isn't available
  fi
fi

# Homebrew early path (macOS)
if [[ -d "/opt/homebrew/bin" ]]; then
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
elif [[ -d "/usr/local/bin" ]]; then
  export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
fi

export PATH="$HOME/.local/bin:$PATH"
