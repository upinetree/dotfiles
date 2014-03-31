# Path Settings
#------------------

# default path
export PATH=/usr/local/bin:$PATH
export PATH=$HOME/bin:$PATH

# rbenv
export PATH=$HOME/.rbenv/bin:$PATH
export PATH=$HOME/.rbenv/shims:$PATH
eval "$(rbenv init -)"
source ~/.rbenv/completions/rbenv.bash

# postgresql
export PGDATA=/usr/local/var/postgres

# Rabbit
# export DYLD_LIBRARY_PATH=/usr/local/opt/cairo/lib

# Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

# git
source ~/bin/git-completion.bash

# gcc setting for installing therubyracer gem
export CC=/usr/local/Cellar/apple-gcc42/4.2.1-5666.3/bin/gcc-4.2
export CXX=/usr/local/Cellar/apple-gcc42/4.2.1-5666.3/bin/g++-4.2
export CPP=/usr/local/Cellar/apple-gcc42/4.2.1-5666.3/bin/cpp-4.2

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

# Default to human readable figures
alias df='df -h'
alias du='du -h'
alias du1='du -h -d1'

# Some shortcuts for different directory listings
alias ll='ls -aCFlh'
alias ls='ls -ACF'
alias l='ls'

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

# tmuxinator
# source ~/.tmuxinator/tmuxinator.bash

# rake task chain
alias db_fixup='be rake db:drop db:create db:migrate test_data:create'
alias parallel_db_fixup='be rake parallel:drop parallel:create parallel:migrate'
alias parallel_spec='be rake parallel:migrate parallel:spec'
alias resql='mysql.server restart'
# parallel:prepare does not work when mysql partitioning is applied
# alias rake_parallel_spec='be rake db:migrate parallel:prepare parallel:spec'

