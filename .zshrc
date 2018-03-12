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
export HISTFILE=${HOME}/.zsh_history
export HISTSIZE=1000
export SAVEHIST=100000

setopt extended_history
setopt hist_ignore_dups
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt hist_expire_dups_first
setopt hist_save_no_dups
# 複数端末感での共有とタイムスタンプ
setopt share_history

# Miscs
#------------------
# rbenv
if [ -d ~/.rbenv ]; then
  export PATH=$HOME/.rbenv/bin:$PATH
  eval "$(rbenv init -)"
  source ~/.rbenv/completions/rbenv.zsh
fi

# nodenv
if [ -d ~/.nodenv ]; then
  eval "$(nodenv init -)"
fi

# compinit
which brew > /dev/null && fpath=($(brew --prefix)/share/zsh/site-functions $fpath) # from Homebrew
autoload -U compinit
compinit -u

# completions
zstyle ':completion:*' use-cache yes

# 環境依存の追加設定はここに定義（上書きできるよう最後に読み込む）
[ -f ~/.env.zsh ] && source ~/.env.zsh

# OSX 固有
#------------------
if [ $(uname) = "Darwin" ]; then
  # 任意のコマンドが終わったら通知
  display_notification() {
    $*
    tput bel
    osascript -e 'display notification "Processes are done." with title "Back To Working!"'
  }
  alias dn=display_notification

  mute_volume() {
    osascript -e "set volume output muted true"
    osascript -e "get volume settings"
  }
  alias vmute=mute_volume

  alias ssaver='open -a ScreenSaverEngine'
fi
