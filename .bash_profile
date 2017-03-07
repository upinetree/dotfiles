# Path Settings
#------------------

# local bin path
export PATH=/usr/local/bin:$PATH
export PATH=$HOME/bin:$PATH

# rbenv
if [ -d ~/.rbenv ]; then
  export PATH=$HOME/.rbenv/bin:$PATH
  eval "$(rbenv init -)"
  source ~/.rbenv/completions/rbenv.bash
fi

# postgresql
export PGDATA=/usr/local/var/postgres

# git
source ~/bin/git-completion.bash

# golang
export GOPATH=$HOME/.go
export PATH=$PATH:$GOPATH/bin

# Shell Options
#------------------

# shopt -s nocaseglob	# Use case-insensitive filename globbing
# shopt -s histappend
shopt -s cdspell
shopt -s dotglob

export LANGUAGE='ja_JP.UTF-8'
export LANG='ja_JP.UTF-8'
export LC_ALL='ja_JP.UTF-8'
export PAGER='less -Ou8'
export EDITOR='vim'

# ls colors
export CLICOLOR=1
export LSCOLORS=DxGxcxdxCxegedabagacad

# source-highlight
export LESS='-R'
export LESSOPEN='| /usr/local/bin/src-hilite-lesspipe.sh %s'

# Don't put duplicate lines in the history.
export HISTCONTROL=$HISTCONTROL${HISTCONTROL+,}ignoredups

# prompt
export PS1="\[\e[1;36m\]\u@\h: \[\e[0;37m\]\W\\$ \[\e[00m\]"

# Aliases
#------------------

# Interactive operation...
alias rm='rm -i'
# alias cp='cp -i'
# alias mv='mv -i'

# File systems
alias df='df -h'
alias du1='du -h -d1'
alias du='du -h'
alias l='ls'
alias ll='ls -aCFlh'
alias ls='ls -ACF'

# DBs
alias my="mysql"
alias my_="mysql --pager='less -S'"
alias my-restart='mysql.server restart'
alias pg-start='pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start'
alias pg-stop='pg_ctl -D /usr/local/var/postgres stop -s -m fast'

# Misc :)
alias src='source ~/.bash_profile'
alias grep='grep --color=auto'		# show differences in colour
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias whence='type -a' 				# where, of a sort
alias vi='vim'
alias be='bundle exec'
alias ni='~/bin/nicorepo/bin/nicorepo i'
alias s='subl'
