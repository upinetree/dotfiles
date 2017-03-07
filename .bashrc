# shopt -s nocaseglob	# Use case-insensitive filename globbing
# shopt -s histappend
shopt -s cdspell
shopt -s dotglob

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
