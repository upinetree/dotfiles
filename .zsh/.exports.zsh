export PATH=$HOME/bin:$PATH
type brew &> /dev/null && export PATH="/usr/local/sbin:$PATH"

# git
# NOTE: diff-highlightが後々デフォルトになったら削除
export PATH=/usr/local/share/git-core/contrib/diff-highlight:$PATH

# postgresql
export PGDATA=/usr/local/var/postgres

# python
export PATH=$HOME/.local/bin:$PATH

# go
type go &> /dev/null && export PATH=$(go env GOPATH)/bin:$PATH

# enhancd
export ENHANCD_HOOK_AFTER_CD=pwd

# ripgrep
export RIPGREP_CONFIG_PATH=~/.ripgreprc

# Shell Options
#------------------

# languages
export LANGUAGE='ja_JP.UTF-8'
export LANG='ja_JP.UTF-8'
export LC_ALL='ja_JP.UTF-8'
export PAGER='less -Ou8'
export EDITOR='vim'
export LESSCHARSET=utf-8

# colors
export COLORTERM=truecolor
export CLICOLOR=1
export LSCOLORS=DxGxcxdxCxegedabagacad

# less options
export LESS='--no-init --quit-if-one-screen --RAW-CONTROL-CHARS --LONG-PROMPT'
# Use source-highlight for less
export LESSOPEN='| /usr/local/bin/src-hilite-lesspipe.sh %s'

# Don't put duplicate lines in the history.
export HISTCONTROL=$HISTCONTROL${HISTCONTROL+,}ignoredups
