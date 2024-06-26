# zsh
alias zshrc='vim ~/.zshrc'
alias reload='exec $SHELL -l'

# File systems
alias cdg='ghq list -p | fzf | cd'
alias dirs='dirs -v'
alias df='df -h'
alias du='du -h'
alias du1='du -h -d1'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias l='ls'
alias ll='ls -aCFlh'
alias ls='ls -ACF'
alias rm='rm -i'

# git
alias g='git'
alias ga='git a'
alias gci='git ci'
alias gco='git branch -a | fzf | xargs git checkout'
alias gsw='git branch | fzf | xargs git switch'
alias gct='git tag | fzf | xargs git checkout'
alias gd='git df'
alias gdc='git dfc'
alias gf='git fetch'
alias gl='git lg'
alias gp='git pull'
alias gs='git s'
alias gm='git sm'
alias t='tig'

# DBs
alias my="mysql"
alias my_="mysql --pager='less -S'"
alias my-restart='mysql.server restart'
alias pg-start='pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start'
alias pg-stop='pg_ctl -D /usr/local/var/postgres stop -s -m fast'

# Misc :)
alias be='bundle exec'
alias dev='devcontainer open'
alias f='fg'
alias v='vim'
alias dc='docker compose' # NOTE: overrides dc command
alias dcps='docker compose ps'
alias laws='aws --profile=local --endpoint-url=http://localhost:4566'
type gsed &> /dev/null && alias sed='gsed'

dhist() {
  LC_ALL=C sed -i '.bak' "/$1/d" $HISTFILE
}

d() {
  diff -u "$@" | delta
}

sshf() {
  grep -w Host ~/.ssh/config | awk '{print $2}' | fzf | xargs -o -n 1 ssh
}

gwt() {
  WT_DIR="tmp/worktree"
  GIT_CDUP_DIR=`git rev-parse --show-toplevel`
  git worktree add ${GIT_CDUP_DIR}/${WT_DIR}/$1 -b $1
  cd ${GIT_CDUP_DIR}/${WT_DIR}/$1
}

http-status-code() {
  ruby -rrack -e 'puts Rack::Utils::HTTP_STATUS_CODES[ARGV[0].to_i]' -- $1
}

# for WSL
if [ -n "$WSLENV" ]; then
  alias pbcopy='win32yank.exe -i'
  alias pbpaste='win32yank.exe -o'
  alias v=nvim
fi
