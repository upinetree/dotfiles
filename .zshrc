# Sources
#------------------
[ -f ~/.zsh/.oh-my-zsh.zsh ] && source ~/.zsh/.oh-my-zsh.zsh
[ -f ~/.zsh/.exports.zsh ] && source ~/.zsh/.exports.zsh
[ -f ~/.zsh/.aliases.zsh ] && source ~/.zsh/.aliases.zsh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Miscs
#------------------
# rbenv
export PATH=$HOME/.rbenv/bin:$PATH
export PATH=$HOME/.rbenv/shims:$PATH    # for tmux $PATH ordering
eval "$(rbenv init -)"
source ~/.rbenv/completions/rbenv.zsh

# git
fpath=($(brew --prefix)/share/zsh/site-functions $fpath)
autoload -U compinit
compinit -u

# Histories
#------------------
setopt hist_ignore_dups
# 複数端末感での共有
setopt share_history
