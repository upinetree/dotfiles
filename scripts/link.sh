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
}

unlink_all() {
  for dotfile_map in "${DOTFILE_MAPS[@]}"
  do
    src_dst=($dotfile_map)

    log "unlink ${src_dst[1]}"
    eval "unlink ${src_dst[1]}"
  done
}

link_all() {
  for dotfile_map in "${DOTFILE_MAPS[@]}"
  do
    log "ln -s $dotfile_map"
    eval "ln -s $dotfile_map"
  done
}

listup_dotfiles() {
  export DOTFILE_MAPS
  DOTFILE_MAPS=(
    "~/.dotfiles/.gemrc            ~/.gemrc"
    "~/.dotfiles/.gitconfig        ~/.gitconfig"
    "~/.dotfiles/.gitignore        ~/.gitignore"
    "~/.dotfiles/.tigrc            ~/.tigrc"
    "~/.dotfiles/.tmux.conf        ~/.tmux.conf"
    "~/.dotfiles/.vim/colors       ~/.vim/colors"
    "~/.dotfiles/.vimrc            ~/.vimrc"
    "~/.dotfiles/.zsh/.aliases.zsh ~/.zsh/.aliases.zsh"
    "~/.dotfiles/.zsh/.exports.zsh ~/.zsh/.exports.zsh"
    "~/.dotfiles/.zsh/.zplug.zsh   ~/.zsh/.zplug.zsh"
    "~/.dotfiles/.zshrc            ~/.zshrc"
  )

  if [ "$PLATFORM" = "osx" ]; then
    DOTFILE_MAPS+=(
      "~/.dotfiles/osx/.slate                  ~/.slate"
      "~/.dotfiles/osx/.vimperatorrc           ~/.vimperatorrc"
      "~/.dotfiles/osx/bin/git-completion.bash ~/bin/git-completion.bash"
    )
  fi
}

echo_conditions() {
  log info "------- platform ------"
  log info "$PLATFORM"
  log info "--- target dotfiles ---"
  for map in "${DOTFILE_MAPS[@]}"
  do
    log info "$map"
  done
  log info "-----------------------"
}

## Entry Point
init
echo_conditions
run
