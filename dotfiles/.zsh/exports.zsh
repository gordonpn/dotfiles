#!/bin/bash

export EDITOR="$VISUAL"
export ENHANCD_FILTER="fzf"
export ENHANCD_HYPHEN_NUM="20"
export FZF_DEFAULT_COMMAND='ag --hidden --ignore .git -f -g "" --depth=-1'
export GIT_EDITOR=vim
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LESS="-i -RJ -+E"
export LESSCHARSET=utf-8
export MANPATH="/usr/local/man:$MANPATH"
export PATH="$HOME/bin:$PATH"
export SPROMPT="Correct $fg[red]%R$reset_color to $fg[green]%r$reset_color? [Yes, No, Abort, Edit] "
export VISUAL=vim
export YSU_MESSAGE_POSITION="after"
export YSU_MODE=ALL
export YSU_MESSAGE_FORMAT="\e[1mFound existing %alias_type for \e[35m\"%command\"\e[39m. You should use: \e[31m\"%alias\"\e[0m\e[39m"
export _MENU_THEME=legacy
export MCFLY_LIGHT=TRUE
export MCFLY_KEY_SCHEME=vim
export MCFLY_FUZZY=2
export MCFLY_HISTORY_LIMIT=10000
export MCFLY_RESULTS=20
export ZSH_ALIAS_FINDER_AUTOMATIC=true

export FZF_DEFAULT_OPTS="
  --layout=reverse
  --height 40%
  --prompt='λ -> '
  --ansi
"
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS' --color=fg:#808080,bg:#ffffff,hl:#0069d1 --color=fg+:#000000,bg+:#e3e3e3,hl+:#0069d1 --color=info:#afaf87,prompt:#d7005f,pointer:#19d400 --color=marker:#00d435,spinner:#3451c7,header:#009494'
#!/bin/bash

HIGHLIGHT=$(which src-hilite-lesspipe.sh)
BREW=$(brew --prefix)

# export BROWSER="firefox developer edition"
export BAT_PAGER="less -RF"
export BAT_STYLE="plain"
export BAT_THEME="GitHub"
export DELTA_PAGER="less -RF"
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1
export DOCKER_CLI_EXPERIMENTAL=enabled
export DOTFILES_ROOT="$HOME/workspace/dotfiles"
export FZF_BASE="/usr/local/bin/fzf"
export GNUTERM=qt
export GOPATH="$HOME/go"
export HOMEBREW_FORCE_VENDOR_RUBY=1
export LESSOPEN="| $HIGHLIGHT %s"
export LESS=" -RF"
export PATH="$BREW/opt/coreutils/libexec/gnubin:$PATH"
export PATH="$BREW/opt/findutils/libexec/gnubin:$PATH"
export PATH="$HOME/.serverless/bin:$PATH"
export PATH="$HOME/workspace/bin:$PATH"
export PATH="/Library/TeX/texbin/:$PATH"
export PATH="/usr/local/opt/curl/bin:$PATH"
export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
export PATH="/usr/local/opt/make/libexec/gnubin:$PATH"
export PATH="/usr/local/opt/ssh-copy-id/bin:$PATH"
export PATH="/usr/local/sbin:$PATH"
export PATH="/Users/gordonpn/.local/bin:$PATH"
export PIP_REQUIRE_VIRTUALENV=true
export AUTOSWITCH_DEFAULT_REQUIREMENTS="$HOME/.requirements.txt"
export AUTOSWITCH_DEFAULT_PYTHON="/Users/gordonpn/.pyenv/shims/python"
export PATH="/Users/gordonpn/.local/bin:$PATH"
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="$PATH:$HOME/.rvm/bin"
export JAVA_HOME="/Library/Java/JavaVirtualMachines/temurin-19.jdk/Contents/Home"
export LS_COLORS="$(vivid generate ayu)"
export PNPM_HOME="/Users/gordonpn/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
export PATH="/Users/gordonpn/go/bin:$PATH"
#!/bin/bash

export DOCKER_CLI_EXPERIMENTAL=enabled
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1
export DOMAIN="gordon-pn.com"
export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64/"
export PATH="$HOME/.local/bin:/usr/sbin:/sbin:$PATH"
export PATH="$HOME/bin:/usr/local/bin:$PATH"
export PATH="$JAVA_HOME/bin:$PATH"
export TZ=America/Toronto
export DOTFILES_ROOT="/home/gordonpn/workspace/dotfiles"
export FZF_BASE="/usr/bin/fzf"
