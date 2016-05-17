export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH=$HOME/bin:$PATH
export PATH=$HOME/.nodebrew/current/bin:$PATH

# postgresql
export PGDATA=/usr/local/var/postgres

# Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

# for ruby build
export CC=clang

# go
export GOPATH=$HOME/.go
export PATH=$PATH:$GOPATH/bin

# Shell Options
#------------------

# languages
export LANGUAGE='ja_JP.UTF-8'
export LANG='ja_JP.UTF-8'
export LC_ALL='ja_JP.UTF-8'
export PAGER='less -Ou8'
export EDITOR='vim'
export LESSCHARSET=utf-8

# ls colors
export CLICOLOR=1
export LSCOLORS=DxGxcxdxCxegedabagacad

# source-highlight
export LESS='-R'
export LESSOPEN='| /usr/local/bin/src-hilite-lesspipe.sh %s'

# Don't put duplicate lines in the history.
export HISTCONTROL=$HISTCONTROL${HISTCONTROL+,}ignoredups
