set -u

# TODO: link.sh と共通化
detect_platform() {
  export PLATFORM
  case "$(uname)" in
    *Darwin*) PLATFORM='osx'     ;;
    *Linux*)  PLATFORM='linux'   ;;
    *)        echo 'Your platform is not supported'
              exit 0 ;;
  esac
}

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
}

detect_platform

if [ -f /bin/zsh ]; then
  echo "Zsh is already installed"
else
  setup_zsh
fi
