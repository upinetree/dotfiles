set -u

. ./scripts/lib.sh

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
  for dotfile_map in "${DOTFILE_MAPS[@]}"; do
    src_dst=($dotfile_map)

    log "unlink ${src_dst[1]}"
    eval "unlink ${src_dst[1]}"
  done
}

link_all() {
  for dotfile_map in "${DOTFILE_MAPS[@]}"; do
    log "ln -s $dotfile_map"
    eval "ln -s $dotfile_map"
  done
}

listup_dotfiles() {
  export DOTFILE_MAPS
  DOTFILE_MAPS=(
    "~/.dotfiles/.gemrc                ~/.gemrc"
    "~/.dotfiles/.gitconfig            ~/.gitconfig"
    "~/.dotfiles/.gitignore            ~/.gitignore"
    "~/.dotfiles/.ripgreprc            ~/.ripgreprc"
    "~/.dotfiles/.tigrc                ~/.tigrc"
    "~/.dotfiles/.tmux.conf            ~/.tmux.conf"
    "~/.dotfiles/.vim/colors           ~/.vim/colors"
    "~/.dotfiles/.vimrc                ~/.vimrc"
    "~/.dotfiles/.zsh/.aliases.zsh     ~/.zsh/.aliases.zsh"
    "~/.dotfiles/.zsh/.exports.zsh     ~/.zsh/.exports.zsh"
    "~/.dotfiles/.zsh/.zplug.zsh       ~/.zsh/.zplug.zsh"
    "~/.dotfiles/.zshrc                ~/.zshrc"
    "~/.dotfiles/.config/nvim/init.vim ~/.config/nvim/init.vim"
    "~/.dotfiles/.config/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml"
    "~/.dotfiles/.config/mise/.config.toml        ~/.config/mise/config.toml"
    "~/.dotfiles/default-gems          ~/.config/mise/default-gems"
    "~/.dotfiles/.claude/settings.json ~/.claude/settings.json"
    "~/.dotfiles/.claude/commands      ~/.claude/commands"
  )

  if [ "$PLATFORM" = "osx" ]; then
    DOTFILE_MAPS+=(
      "~/.dotfiles/osx/.slate                  ~/.slate"
      "~/.dotfiles/osx/.vimperatorrc           ~/.vimperatorrc"
      "~/.dotfiles/osx/bin/git-completion.bash ~/bin/git-completion.bash"
      "~/.dotfiles/.config/skhd/skhdrc         ~/.config/skhd/skhdrc"
      "~/.dotfiles/.config/yabai/yabaicmd      ~/.config/yabai/yabaicmd"
    )
  fi
}

echo_conditions() {
  log info "------- platform ------"
  log info "$PLATFORM"
  log info "--- target dotfiles ---"
  for map in "${DOTFILE_MAPS[@]}"; do
    log info "$map"
  done
  log info "-----------------------"
}

## Entry Point
init
echo_conditions
run
