run() {
  detect_platform
  setup_dirs
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

setup_dirs() {
  mkdir ~/.zsh
  mkdir ~/.vim

  if [ "$PLATFORM" = "osx" ]; then
    mkdir ~/bin
  fi
}

unlink_all() {
  unlink ~/.gemrc
  unlink ~/.gitconfig
  unlink ~/.gitignore
  unlink ~/.tmux.conf
  unlink ~/.zshrc
  unlink ~/.zsh/.aliases.zsh
  unlink ~/.zsh/.exports.zsh
  unlink ~/.vimrc
  unlink ~/.vim/colors
  unlink ~/.slate
  unlink ~/.vimperatorrc

  if [ "$PLATFORM" = "osx" ]; then
    unlink ~/bin/git-completion.bash
    unlink ~/bin/login-shell
  fi
}

link_all() {
  ln -s ~/.dotfiles/.gemrc                      ~/.gemrc
  ln -s ~/.dotfiles/.gitconfig                  ~/.gitconfig
  ln -s ~/.dotfiles/.gitignore                  ~/.gitignore
  ln -s ~/.dotfiles/.tmux.conf                  ~/.tmux.conf
  ln -s ~/.dotfiles/.zshrc                      ~/.zshrc
  ln -s ~/.dotfiles/.zsh/.aliases.zsh           ~/.zsh/.aliases.zsh
  ln -s ~/.dotfiles/.zsh/.exports.zsh           ~/.zsh/.exports.zsh
  ln -s ~/.dotfiles/.vimrc                      ~/.vimrc
  ln -s ~/.dotfiles/.vim/colors                 ~/.vim/colors

  if [ "$PLATFORM" = "osx" ]; then
    ln -s ~/.dotfiles/osx/.slate                  ~/.slate
    ln -s ~/.dotfiles/osx/.vimperatorrc           ~/.vimperatorrc
    ln -s ~/.dotfiles/osx/bin/git-completion.bash ~/bin/git-completion.bash
    ln -s ~/.dotfiles/osx/bin/login-shell         ~/bin/login-shell
  fi
}

run
