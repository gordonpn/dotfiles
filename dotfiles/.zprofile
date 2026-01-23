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

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export BAT_STYLE="plain"
export BAT_THEME="Catppuccin Frappe"

export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude node_modules'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude node_modules'
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }--ignore-case"
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }--style=full --color=dark"

export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

export HISTORY_SUBSTRING_SEARCH_FUZZY=1
export HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1

export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Allow Nerd Font glyphs (PUA) in less
export LESSUTFCHARDEF='23fb-23fe:w,2665-2665:w,2b58-2b58:w,e000-e00a:w,e0a0-e0a3:p,e0b0-e0bf:p,e0c0-e0c8:w,e0ca-e0ca:w,e0cc-e0d7:w,e200-e2a9:w,e300-e3e3:w,e5fa-e6b5:w,e700-e7c5:w,ea60-ec1e:w,ed00-efce:w,f000-f2ff:w,f300-f375:w,f400-f533:w,f0001-f1af0:w'
export LESSUTFBINFMT='*n%C'

export ZPWR_EXPAND_TO_HISTORY=true
export ZPWR_EXPAND=true
export ZPWR_EXPAND_SECOND_POSITION=true

export MANPAGER="sh -c 'col -bx | bat -l man -p'"

export KUBE_EDITOR='nvim'

