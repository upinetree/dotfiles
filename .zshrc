# Sources
#------------------
[ -d ~/.oh-my-zsh ] && source ~/.zsh/.oh-my-zsh.zsh
[ -d ~/.fzf.zsh ]   && source ~/.fzf.zsh

source ~/.zsh/.exports.zsh
source ~/.zsh/.aliases.zsh

# Miscs
#------------------
# rbenv
export PATH=$HOME/.rbenv/bin:$PATH
export PATH=$HOME/.rbenv/shims:$PATH    # for tmux $PATH ordering
eval "$(rbenv init -)"
source ~/.rbenv/completions/rbenv.zsh

# compinit
fpath=($(brew --prefix)/share/zsh/site-functions $fpath) # from Homebrew
autoload -U compinit
compinit -u

# Histories
#------------------
setopt hist_ignore_dups
# 複数端末感での共有
setopt share_history
