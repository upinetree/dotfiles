# Interactive operation...
alias rm='rm -i'
# alias cp='cp -i'
# alias mv='mv -i'

# Default to human readable figures
alias df='df -h'
alias du='du -h'
alias du1='du -h -d1'

# Some shortcuts for different directory listings
alias ll='ls -aCFlh'
alias ls='ls -ACF'
alias l='ls'

# Misc :)
alias src='source ~/.zshrc'
alias zshrc='vim ~/.zshrc'
alias grep='grep --color=auto'		# show differences in colour
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias v='vim'
alias vi='vim'
alias be='bundle exec'
alias bi='bundle install --path vendor/bundle'
alias ni='nicorepo i'
alias s='subl'
alias g='git'
alias gd='git df'
alias gs='git st'
alias gl='git lg'
alias gadp='git adp'
alias f='fg'
alias vssh='vagrant ssh'
alias cdg='cd $(ghq list -p | fzf)'
alias mysql_="mysql --pager='less -S'"

# tmuxinator
# source ~/.tmuxinator/tmuxinator.bash

# rake task chain
alias db_fixup='be rake db:drop db:create db:migrate test_data:create'
alias resql='mysql.server restart'
alias pg-start='pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start'
alias pg-stop='pg_ctl -D /usr/local/var/postgres stop -s -m fast'
