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



if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi
