# zsh
alias zshrc='vim ~/.zshrc'
alias reload='source ~/.zshrc'

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
alias gadp='git adp'
alias gci='git ci'
alias gco='git branch -a | fzf | xargs git checkout'
alias gct='git tag | fzf | xargs git checkout'
alias gd='git df'
alias gdc='git dfc'
alias gf='git ft'
alias gl='git lg'
alias gp='git pull'
alias gs='git st'
alias t='tig'

# DBs
alias my="mysql"
alias my_="mysql --pager='less -S'"
alias my-restart='mysql.server restart'
alias pg-start='pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start'
alias pg-stop='pg_ctl -D /usr/local/var/postgres stop -s -m fast'

# Misc :)
alias be='bundle exec'
alias f='fg'
alias ni='nicorepo i'
alias v='vim'
alias vag='vagrant'
alias vssh='vagrant ssh'
alias dc='docker-compose' # NOTE: overrids dc command

sshf() {
  grep -w Host ~/.ssh/config | awk '{print $2}' | fzf | xargs -o -n 1 ssh
}
