# ZLE は emacs モード。vi モードはまだ慣れないので
# fzf がキーバインドを設定する前に読み込むこと
bindkey -e

# Sources
#------------------
[ -d ~/.oh-my-zsh ] && source ~/.zsh/.oh-my-zsh.zsh
[ -d ~/.zplug ]     && source ~/.zsh/.zplug.zsh
[ -f ~/.fzf.zsh ]   && source ~/.fzf.zsh

source ~/.zsh/.exports.zsh
source ~/.zsh/.aliases.zsh

# Histories
#------------------
setopt hist_ignore_dups
# 複数端末感での共有
setopt share_history

# Miscs
#------------------
# rbenv
if [ -d ~/.rbenv ]; then
  export PATH=$HOME/.rbenv/bin:$PATH
  eval "$(rbenv init -)"
  source ~/.rbenv/completions/rbenv.zsh
fi

# compinit
which brew > /dev/null && fpath=($(brew --prefix)/share/zsh/site-functions $fpath) # from Homebrew
autoload -U compinit
compinit -u

# 環境依存の追加設定はここに定義（上書きできるよう最後に読み込む）
[ -f ~/.env.zsh ] && source ~/.env.zsh
