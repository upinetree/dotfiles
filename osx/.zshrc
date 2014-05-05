# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="robbyrussell"

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to disable command auto-correction.
# DISABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

export PATH=$HOME/bin:/usr/local/bin:$PATH
# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"


# Path Settings
#------------------

# default path
export PATH=/usr/local/bin:$PATH
export PATH=$HOME/bin:$PATH

# rbenv
export PATH=$HOME/.rbenv/bin:$PATH
export PATH=$HOME/.rbenv/shims:$PATH    # for tmux $PATH ordering
eval "$(rbenv init -)"
source ~/.rbenv/completions/rbenv.zsh

# npm
export PATH=/usr/local/lib/node_modules/karma/bin:$PATH

# postgresql
export PGDATA=/usr/local/var/postgres

# Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

# gcc setting for installing therubyracer gem
export CC=/usr/local/Cellar/apple-gcc42/4.2.1-5666.3/bin/gcc-4.2
export CXX=/usr/local/Cellar/apple-gcc42/4.2.1-5666.3/bin/g++-4.2
export CPP=/usr/local/Cellar/apple-gcc42/4.2.1-5666.3/bin/cpp-4.2

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
alias src='source ~/.zshrc'
alias grep='grep --color=auto'		# show differences in colour
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias vi='vim'
alias be='bundle exec'
alias bi='bundle install --path vendor/bundle'
alias ni='nicorepo i'
alias s='subl'
alias g='git'

# tmuxinator
# source ~/.tmuxinator/tmuxinator.bash

# rake task chain
alias db_fixup='be rake db:drop db:create db:migrate test_data:create'
alias parallel_db_fixup='be rake parallel:drop parallel:create parallel:migrate'
alias parallel_spec='be rake parallel:migrate parallel:spec'
alias resql='mysql.server restart'
# parallel:prepare does not work when mysql partitioning is applied
# alias rake_parallel_spec='be rake db:migrate parallel:prepare parallel:spec'

