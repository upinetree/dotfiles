set -u

. ./etc/scripts/lib.sh

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
  mkdir ~/.zsh
  mkdir ~/.vim

  if [ "$PLATFORM" = "osx" ]; then
    mkdir ~/bin
  fi
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
    "~/.dotfiles/.gemrc              ~/.gemrc"
    "~/.dotfiles/.gitconfig          ~/.gitconfig"
    "~/.dotfiles/.gitignore          ~/.gitignore"
    "~/.dotfiles/.tmux.conf          ~/.tmux.conf"
    "~/.dotfiles/.zshrc              ~/.zshrc"
    "~/.dotfiles/.zsh/.aliases.zsh   ~/.zsh/.aliases.zsh"
    "~/.dotfiles/.zsh/.exports.zsh   ~/.zsh/.exports.zsh"
    "~/.dotfiles/.zsh/.oh-my-zsh.zsh ~/.zsh/.oh-my-zsh.zsh"
    "~/.dotfiles/.vimrc              ~/.vimrc"
    "~/.dotfiles/.vim/colors         ~/.vim/colors"
    "~/.dotfiles/bin/login-shell     ~/bin/login-shell"
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
