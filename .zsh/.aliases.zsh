# zsh
alias zshrc='vim ~/.zshrc'
alias reload='exec $SHELL -l'

# File systems
alias cdg='ghq list -p | fzf | cd'
alias dirs='dirs -v'
alias df='df -h'
alias du='du -h'
alias du1='du -h -d1'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias l='ls'
alias ll='ls -aCFlh'
alias ls='ls -ACF'
alias rm='rm -i'

# git
alias g='git'
alias ga='git a'
alias gci='git ci'
alias gco='git branch -a | fzf | xargs git checkout'
alias gsw='git branch | fzf | xargs git switch'
alias gct='git tag | fzf | xargs git checkout'
alias gd='git df'
alias gdc='git dfc'
alias gf='git fetch'
alias gl='git lg'
alias gp='git pull'
alias gs='git s'
alias gm='git sm'
alias t='tig'

# DBs
alias my="mysql"
alias my_="mysql --pager='less -S'"
alias my-restart='mysql.server restart'
alias pg-start='pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start'
alias pg-stop='pg_ctl -D /usr/local/var/postgres stop -s -m fast'

# Misc :)
alias be='bundle exec'
alias dev='devcontainer open'
alias f='fg'
alias v='vim'
alias dc='docker compose' # NOTE: overrides dc command
alias dcps='docker compose ps'
alias laws='aws --profile=local --endpoint-url=http://localhost:4566'
type gsed &> /dev/null && alias sed='gsed'

# usage: rgl <rg-args>
# `rg` with sipmle output (path:line_number<TAB>line_text)
# e.g.)
#   $ rgl "func\(" .zsh/
#   .zsh/.aliases.zsh:114   ls-func() {\n
#   .zsh/.aliases.zsh:118   show-func() {\n
rgl() {
  rg --json $@ | jq -r 'select(.type == "match") | .data | [(.path.text + ":" + (.line_number|tostring)), .lines.text] | @tsv'
}

# usage: dhist <keyword>
# Delete history lines that contain the keyword
dhist() {
  LC_ALL=C sed -i '.bak' "/$1/d" $HISTFILE
}

d() {
  diff -u "$@" | delta
}

sshf() {
  grep -w Host ~/.ssh/config | awk '{print $2}' | fzf | xargs -o -n 1 ssh
}

gwt() {
  WT_DIR="tmp/worktree"
  GIT_CDUP_DIR=`git rev-parse --show-toplevel`
  git worktree add ${GIT_CDUP_DIR}/${WT_DIR}/$1 -b $1
  cd ${GIT_CDUP_DIR}/${WT_DIR}/$1
}

# usege: git-branch-vault <branch1> <branch2> ...
# It renames the branch to vault/<branch>.
# If the environment variable `VAULT` is provided, it uses it as the vault name.
git-branch-vault() {
  local branches=($@)
  local vault=${VAULT:-vault}
  for branch in ${branches[@]}; do
    git branch -m $branch $vault/$branch
    echo "Renamed $branch to $vault/$branch"
  done
}
compdef _git git-branch-vault=git-branch

http-status-code() {
  ruby -rrack -e 'puts Rack::Utils::HTTP_STATUS_CODES[ARGV[0].to_i]' -- $1
}

cop() {
  local files=($(git diff --name-only --diff-filter=AM "*.rb"))
  if [[ ${#files[@]} -eq 0 ]]; then
    # 差分がなければ main ブランチからの差分を取得
    local main=$(git main)
    files=($(git diff --name-only --diff-filter=AM "$main" "*.rb"))
  fi

  if [[ ${#files[@]} -ne 0 ]]; then
    echo "Executing: bundle exec rubocop -A ${files[@]}"
    bundle exec rubocop -A "${files[@]}"
  else
    echo "No files to lint."
  fi
}

ls-func() {
  print -l ${(ok)functions[(I)[^_]*]} # _ で始まる関数は除外
}

show-func() {
  if [[ -n $1 && -n ${functions[$1]} ]]; then
    print -r -- "${functions[$1]}"
  else
    print "Function '$1' not found."
  fi
}

edit-func() {
  vim ~/.zsh/.aliases.zsh
}

# for WSL
if [ -n "$WSLENV" ]; then
  alias pbcopy='win32yank.exe -i'
  alias pbpaste='win32yank.exe -o'
  alias v=nvim
fi
