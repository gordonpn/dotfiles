eval "$(/opt/homebrew/bin/brew shellenv)"

if command -v nvim >/dev/null 2>&1; then
  export EDITOR="nvim"
elif command -v vim >/dev/null 2>&1; then
  export EDITOR="vim"
else
  export EDITOR="nano"
fi
export VISUAL="$EDITOR"

export LESS="-g -i -M -R -S -w -z-4 -F -X"
export LANG="${LANG:-en_US.UTF-8}"
export LANGUAGE="${LANGUAGE:-en}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export FUNCNEST=1000000
export EZA_CONFIG_DIR="$HOME/.config/eza"
export PAGER="less"

export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude node_modules'

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export BAT_STYLE="plain"

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude node_modules'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

export HISTORY_SUBSTRING_SEARCH_FUZZY=1
export HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1
