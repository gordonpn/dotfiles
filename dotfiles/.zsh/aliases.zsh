#!/bin/bash

# modern defaults
alias al="alias | ag"
alias hs='history | grep'
alias htop="htop --sort-key=PERCENT_CPU"
# shell
alias update="source $HOME/.zshrc"
alias reload="exec ${SHELL} -l"
alias path='echo -e ${PATH//:/\\n}'
# network
alias pingdns="ping -c3 8.8.8.8"
alias pingtest="ping -c3 google.com"
alias myip="curl http://ipecho.net/plain; echo"
alias myrouter="netstat -nr | grep default"
alias localip="ipconfig getifaddr en0"
# ls
alias cls="clear && ls"
alias l="exa -d */ -1"
alias la="exa -1 --icons --all --group-directories-first --color=always --classify --reverse --sort=modified"
alias ll="exa --time-style=long-iso --icons --all --group-directories-first --color=always --classify --long --git --header"
alias ls="exa -1 --icons --all --group-directories-first --color=always --classify"
alias tree='exa --tree --all --ignore-glob="node_modules|venv|.mypy_cache|.idea|.git|__pycache__|.vscode|.next|virtualenv|vendor"'
# git
alias gaa='git add .'
alias gac="git add -v . && git commit"
alias gapa='git add --intent-to-add . && git add --patch'
alias gb="git branch --sort=-committerdate --verbose"
alias gbdr='git push origin --delete'
alias gc='git commit'
alias 'gc!'='git commit --amend'
alias gca='git commit -a'
alias 'gca!'='git commit -a --amend'
alias 'gcan!'='git commit -a --no-edit --amend'
alias gcnv="git commit --allow-empty --no-verify"
alias gcob="git checkout -b"
alias gcod="git checkout develop"
# alias gcom="git checkout $(git default-branch)"
alias gcot="git checkout -t"
alias gcount="git shortlog -sn --all --no-merges"
alias gd="git diff"
alias gdc="diff --name-only --diff-filter=U"
alias gds="git diff --staged"
alias gdw="git diff --word-diff -w"
alias gep='git add . && git commit --allow-empty - m "intentionally empty debug push" && git push origin $(git_current_branch)'
alias ggc="git gc --prune=now --aggressive"
alias giu="git status --porcelain | grep '^??' | cut -c4- >> .gitignore"
alias glb='git branch --sort="-committerdate" --format="%(color:green)%(committerdate:relative)%(color:reset) %(refname:short)"'
alias glog="git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --all"
alias glogg='glog --decorate'
alias glogs='git log --all --decorate --stat --date=iso'
alias grhs1='git reset --soft HEAD~1'
alias grhs='git reset --soft'
alias grss='git restore --staged'
alias gsh="git show -w"
alias gst="git status --show-stash --untracked-files=all"
alias gupod="git pull --autostash --rebase origin develop"
alias gupo="git pull --autostash --rebase origin"
alias lg='lazygit'
# docker
alias dc='docker container'
alias dcls='docker container ls'
alias dclsf='docker container ls --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}\t{{.Status}}"'
alias ldoc='lazydocker'
alias ctop='ctop -i'
alias dcupb='docker-compose up --build'
# npm
alias ni='npm install'
alias nu='npm uninstall'
alias nid='npm install --save-dev'
alias nig='npm install --global'
alias nt='npm test'
alias nit='npm install && npm test'
alias nk='npm link'
alias naf='npm audit fix'
alias nr='npm run'
alias ns='npm start'
alias nf='npm cache clean && rm -rf node_modules && npm install'
alias nlg='npm list --global --depth=0'
alias npkill='npx npkill'
alias depcheck='npx depcheck'
alias ncu='npx npm-check-updates'
# Parenting changing perms on / #
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chgrp='chgrp --preserve-root'
# Get week number
alias week='date +%V'
# archives
alias ltar="tar -ztvf"
alias untar="tar -zxvf"
alias atar="tar -cvzf"
#!/bin/bash

# modern defaults
alias cat="bat --paging=never"
alias skl="sk --ansi -i -c 'grep -rI --color=always --line-number "{}" .'"
alias gtop="pnpm dlx gtop"
alias tldr="pnpm dlx tldr"
alias btm="btm --color=default-light"
alias glances="glances --theme-white"
alias yless="jless --yaml"
# Gatekeeper (for installing 3rd party apps)
alias gatekeeperOff="sudo spctl --master-disable"
alias gatekeeperOn="sudo spctl --master-enable"
# sort LaunchPad
alias sortlaunchpad="defaults write com.apple.dock ResetLaunchPad -bool true; killall Dock"
# Clean up LaunchServices to remove duplicates in the “Open With” menu
alias lscleanup="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder"
# shell
alias change='code $DOTFILES_ROOT'
# Brew
alias brews="brew list --formula -1"
alias brewsc="brew list --cask -1"
# GH
alias ghrv="gh repo view --web"
alias ghil="gh issue list"
alias ghis="gh issue status"
# Convenience
alias jsontidy="pbpaste | jq '.'"
alias sql-formatter="npx sql-formatter -u"
alias o="open_command"
alias cpd='copydir'
alias cpf='copyfile'
alias torrent='webtorrent download $(pbpaste) --iina'
alias wakedev='wakeonlan 94:c6:91:12:c8:e2'
alias restartwifi='sudo ifconfig en0 down && sudo ifconfig en0 up'
# python
alias avenv="source .venv/bin/activate"
# themes
alias ncdu="ncdu --color off"
alias mmdc='npx -p @mermaid-js/mermaid-cli mmdc'
#!/bin/bash

# shell
alias change='vim $HOME/.zshrc'
# system
alias sysup='sudo apt-get update'
alias listd='sudo lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL; df -hl'
# network
alias ufwnum="sudo ufw status numbered"
# mail
alias checkmail='sudo less /var/mail/$(whoami)'
alias deletemail='sudo rm /var/mail/$(whoami)'
# zombie processes
alias zombie="ps axo stat,ppid,pid,comm | grep -w defunct"
