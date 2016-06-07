set -u

setup() {
  detect_platform
  listup_dotfiles
}

run() {
  make_base_dirs
  unlink_all
  link_all
}

detect_platform() {
  export PLATFORM
  case "$(uname)" in
    *Darwin*) PLATFORM='osx'     ;;
    *Linux*)  PLATFORM='linux'   ;;
    *)        echo 'Your platform is not supported'
              exit 0 ;;
  esac
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

    echo "unlink ${src_dst[1]}"
    eval "unlink ${src_dst[1]}"
  done
}

link_all() {
  for dotfile_map in "${DOTFILE_MAPS[@]}"
  do
    echo "ln -s $dotfile_map"
    eval "ln -s $dotfile_map"
  done
}

listup_dotfiles() {
  export DOTFILE_MAPS
  DOTFILE_MAPS=(
    "~/.dotfiles/.gemrc            ~/.gemrc"
    "~/.dotfiles/.gitconfig        ~/.gitconfig"
    "~/.dotfiles/.gitignore        ~/.gitignore"
    "~/.dotfiles/.tmux.conf        ~/.tmux.conf"
    "~/.dotfiles/.zshrc            ~/.zshrc"
    "~/.dotfiles/.zsh/.aliases.zsh ~/.zsh/.aliases.zsh"
    "~/.dotfiles/.zsh/.exports.zsh ~/.zsh/.exports.zsh"
    "~/.dotfiles/.vimrc            ~/.vimrc"
    "~/.dotfiles/.vim/colors       ~/.vim/colors"
  )

  if [ "$PLATFORM" = "osx" ]; then
    DOTFILE_MAPS+=(
      "~/.dotfiles/osx/.slate                  ~/.slate"
      "~/.dotfiles/osx/.vimperatorrc           ~/.vimperatorrc"
      "~/.dotfiles/osx/bin/git-completion.bash ~/bin/git-completion.bash"
      "~/.dotfiles/osx/bin/login-shell         ~/bin/login-shell"
    )
  fi
}

echo_conditions() {
  echo "------- platform ------"
  echo "$PLATFORM"
  echo "--- target dotfiles ---"
  for map in "${DOTFILE_MAPS[@]}"
  do
    echo "$map"
  done
  echo "-----------------------"
}

setup
echo_conditions
run
