# File systems
alias rm='rm -i'
alias ll='ls -aCFlh'
alias ls='ls -ACF'
alias l='ls'

# Default to human readable figures
alias df='df -h'
alias du='du -h'
alias du1='du -h -d1'

# git
alias g='git'
alias gd='git df'
alias gs='git st'
alias gl='git lg'
alias gadp='git adp'
alias gci='git ci'

# DBs
alias my="mysql"
alias my_="mysql --pager='less -S'"
alias my-restart='mysql.server restart'
alias pg-start='pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start'
alias pg-stop='pg_ctl -D /usr/local/var/postgres stop -s -m fast'

# rake task chain
alias db_fixup='be rake db:drop db:create db:migrate test_data:create'

# Misc :)
alias zshrc='vim ~/.zshrc'
alias reload='source ~/.zshrc'
alias grep='grep --color=auto'		# show differences in colour
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias v='vim'
alias be='bundle exec'
alias bi='bundle install --path vendor/bundle'
alias ni='nicorepo i'
alias f='fg'
alias vssh='vagrant ssh'
alias cdg='cd $(ghq list -p | fzf)'
