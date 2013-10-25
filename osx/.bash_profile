# Path Settings
#------------------
export PATH=/usr/local/bin:$PATH
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

export DYLD_LIBRARY_PATH=/usr/local/opt/cairo/lib


# Shell Options
#------------------

# shopt -s nocaseglob	# Use case-insensitive filename globbing
# shopt -s histappend
shopt -s cdspell
shopt -s dotglob

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
alias src='source ~/.bash_profile'
alias grep='grep --color=auto'		# show differences in colour
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias whence='type -a' 				# where, of a sort
alias vi='vim'
alias be='bundle exec'
alias nicorepo='~/Repositories/nicorepo/bin/nicorepo'

# tmuxinator
source ~/.tmuxinator/tmuxinator.bash


# Umask
#------------------

# umask 027	# no exec perms for others
# umask 077 # neither group nor others have any perms

### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"
