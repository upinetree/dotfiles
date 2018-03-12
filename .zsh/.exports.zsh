export PATH=$HOME/bin:$PATH

# git
# NOTE: diff-highlightが後々デフォルトになったら削除
export PATH=/usr/local/share/git-core/contrib/diff-highlight:$PATH

# postgresql
export PGDATA=/usr/local/var/postgres

# ruby build
export CC=clang
if [ $(uname) = "Darwin" ]; then
  export CONFIGURE_OPTS="--with-opt-dir=`brew --prefix openssl`"
  export RUBY_CONFIGURE_OPTS="--with-opt-dir=`brew --prefix openssl`"
fi

# go
export GOPATH=$HOME/.go
export PATH=$PATH:$GOPATH/bin

# yarn
type yarn &> /dev/null && export PATH="$PATH:`yarn global bin`"

# enhancd
export ENHANCD_HOOK_AFTER_CD=pwd

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
