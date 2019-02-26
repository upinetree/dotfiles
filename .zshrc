# Operations
#------------------
# ZLE は emacs モード。vi モードはまだ慣れないので
# fzf がキーバインドを設定する前に読み込むこと
bindkey -e

# for safe redirect
set -o noclobber

# completions
zstyle ':completion:*' use-cache yes
zstyle ':completion:*:default' menu select=2

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

# **envs
#------------------
# TODO: Lazy load? (loading them every time cause some performance issue)
# rbenv
if [ -d ~/.rbenv ]; then
  export PATH=$HOME/.rbenv/bin:$PATH
  eval "$(rbenv init -)"
fi

# nodenv
if [ -d ~/.nodenv ]; then
  eval "$(nodenv init -)"
fi

# pyenv
if [ -d ~/.pyenv ]; then
  eval "$(pyenv init -)"
fi

# Functions
#------------------
movtogif() {
  ffmpeg -i "$1" -vf scale=800:-1 -r 10 -f image2pipe -vcodec ppm - |\
  convert -delay 10 -layers Optimize -loop 0 - "${1%.*}.gif"
}

# OSX 固有
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

# Sources
#------------------
source ~/.zsh/.exports.zsh
source ~/.zsh/.aliases.zsh

# 環境依存の追加設定はここに定義（上書きできるよう最後に読み込む）
[ -f ~/.env.zsh ] && source ~/.env.zsh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# NOTE: プラグインマネージャは最後に呼ぶ
# 内部で compinit が実行されるので、.zshrc の他の部分で重複して呼ばないようにするため
[ -d ~/.oh-my-zsh ] && source ~/.zsh/.oh-my-zsh.zsh
[ -d ~/.zplug ]     && source ~/.zsh/.zplug.zsh

# Profiling
#------------------
# NOTE: zprof を以下のコマンドで有効化すると表示される
# echo "zmodload zsh/zprof && zprof" > ~/.zshenv
if (which zprof > /dev/null 2>&1) ;then
  zprof
fi

# Auto added...
#------------------
# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/tmatsumoto/google-cloud-sdk/path.zsh.inc' ]; then source '/Users/tmatsumoto/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/tmatsumoto/google-cloud-sdk/completion.zsh.inc' ]; then source '/Users/tmatsumoto/google-cloud-sdk/completion.zsh.inc'; fi
