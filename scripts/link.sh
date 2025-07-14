set -u

. ./scripts/lib.sh

declare -A DOTFILE_MAPS

init() {
  detect_platform
  listup_dotfiles
}

run() {
  make_base_dirs
  unlink_all
  link_all
}

make_base_dirs() {
  mkdir ~/.vim
  mkdir ~/.zsh
  mkdir ~/bin
  mkdir -p ~/.config/nvim
  mkdir -p ~/.config/yabai
  mkdir -p ~/.config/skhd
  mkdir -p ~/.config/mise
  mkdir -p ~/.config/alacritty
  mkdir -p ~/.claude
}

unlink_all() {
  for src in "${!DOTFILE_MAPS[@]}"; do
    dst="${DOTFILE_MAPS[$src]}"
    log "unlink $dst"
    eval "unlink $dst"
  done
}

link_all() {
  for src in "${!DOTFILE_MAPS[@]}"; do
    dst="${DOTFILE_MAPS[$src]}"
    log "ln -s $src $dst"
    eval "ln -s $src $dst"
  done
}

listup_dotfiles() {
  DOTFILE_MAPS=(
    ["~/.dotfiles/.gemrc"]="~/.gemrc"
    ["~/.dotfiles/.gitconfig"]="~/.gitconfig"
    ["~/.dotfiles/.gitignore"]="~/.gitignore"
    ["~/.dotfiles/.ripgreprc"]="~/.ripgreprc"
    ["~/.dotfiles/.tigrc"]="~/.tigrc"
    ["~/.dotfiles/.tmux.conf"]="~/.tmux.conf"
    ["~/.dotfiles/.vim/colors"]="~/.vim/colors"
    ["~/.dotfiles/.vimrc"]="~/.vimrc"
    ["~/.dotfiles/.zsh/.aliases.zsh"]="~/.zsh/.aliases.zsh"
    ["~/.dotfiles/.zsh/.exports.zsh"]="~/.zsh/.exports.zsh"
    ["~/.dotfiles/.zsh/.zplug.zsh"]="~/.zsh/.zplug.zsh"
    ["~/.dotfiles/.zshrc"]="~/.zshrc"
    ["~/.dotfiles/.config/nvim/init.vim"]="~/.config/nvim/init.vim"
    ["~/.dotfiles/.config/alacritty/alacritty.toml"]="~/.config/alacritty/alacritty.toml"
    ["~/.dotfiles/.config/mise/.config.toml"]="~/.config/mise/config.toml"
    ["~/.dotfiles/default-gems"]="~/.config/mise/default-gems"
    ["~/.dotfiles/.claude/settings.json"]="~/.claude/settings.json"
    ["~/.dotfiles/.claude/commands"]="~/.claude/commands"
  )

  if [ "$PLATFORM" = "osx" ]; then
    DOTFILE_MAPS["~/.dotfiles/osx/.slate"]="~/.slate"
    DOTFILE_MAPS["~/.dotfiles/osx/.vimperatorrc"]="~/.vimperatorrc"
    DOTFILE_MAPS["~/.dotfiles/osx/bin/git-completion.bash"]="~/bin/git-completion.bash"
    DOTFILE_MAPS["~/.dotfiles/.config/skhd/skhdrc"]="~/.config/skhd/skhdrc"
    DOTFILE_MAPS["~/.dotfiles/.config/yabai/yabaicmd"]="~/.config/yabai/yabaicmd"
  fi
}

echo_conditions() {
  log info "------- platform ------"
  log info "$PLATFORM"
  log info "--- target dotfiles ---"
  for src in "${!DOTFILE_MAPS[@]}"; do
    dst="${DOTFILE_MAPS[$src]}"
    log info "$src -> $dst"
  done
  log info "-----------------------"
}

## Entry Point
init
echo_conditions
run
