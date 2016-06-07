mkdir ~/.zsh
mkdir ~/.vim
mkdir ~/bin

detect_platform

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

detect_platform() {
  export PLATFORM
  case "$(uname)" in
    *Darwin*) PLATFORM='osx'     ;;
    *Linux*)  PLATFORM='linux'   ;;
    *)        echo 'Your platform is not supported'
              exit 0 ;;
  esac
}
