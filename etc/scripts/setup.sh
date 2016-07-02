set -u

. ./etc/scripts/lib.sh

setup_zsh() {
  case "$PLATFORM" in
    osx)
      if which "brew" > /dev/null; then
        brew install zsh
      else
        echo "ERROR: homebrew is not exists"
        exit 1
      fi
      ;;
    linux)
      if which "apt-get" > /dev/null; then
        sudo apt-get -y install zsh
      elif which "yum" > /dev/null; then
        sudo yum -y install zsh
      else
        echo "ERROR: apt-get or yum is not exists"
        exit 1
      fi
      ;;
    *)
      echo "ERROR: Your platform is not supported"
      exit 1
      ;;
  esac

  zsh_path="$(which zsh)"

  if ! grep $zsh_path /etc/shells; then
    echo "ERROR: \`$zsh_path\` should be appended in /etc/shells"
    exit 1
  fi

  if chsh -s "$zsh_path"; then
    echo "Setup Zsh is successfully finished!"
  else
    echo "Changing shell to $zsh_path is failed"
  fi
}

## Entry Point
detect_platform

if which zsh > /dev/null; then
  echo "Zsh is already exists"
else
  setup_zsh
fi
