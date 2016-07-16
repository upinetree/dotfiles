set -u

. ./etc/scripts/lib.sh

set_versions() {
  export GO_VERSION="1.6.2"
}

install_zsh() {
  case "$PLATFORM" in
    osx)
      if exists brew; then
        brew install zsh
      else
        log error "ERROR: homebrew is not exists"
        return 1
      fi
      ;;
    linux)
      if exists apt-get; then
        sudo apt-get -y install zsh
      elif exists yum; then
        sudo yum -y install zsh
      else
        log error "ERROR: apt-get or yum is not exists"
        return 1
      fi
      ;;
    *)
      log error "ERROR: Your platform is not supported"
      return 1
      ;;
  esac

  zsh_path="$(which zsh)"

  if ! grep -xq $zsh_path /etc/shells; then
    log error "ERROR: \`$zsh_path\` should be appended in /etc/shells"
    return 1
  fi

  log info "To change shell to $zsh_path, type your password:"
  if chsh -s "$zsh_path"; then
    log success "Changing shell to $zsh_path is successfully finished! Re-Login to apply it."
  else
    log warn "Changing shell to $zsh_path is failed"
  fi
}

install_rbenv() {
  git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
  git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
}

install_fzf() {
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  bash ~/.fzf/install
}

install_brew() {
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

install_go() {
  case "$PLATFORM" in
    osx)
      brew install go
      ;;
    linux)
      local tar="go$GO_VERSION.linux-amd64.tar.gz"

      wget "https://storage.googleapis.com/golang/$tar"

      sudo tar -C /usr/local -xf $tar
      sudo ln -s /usr/local/go/bin/go* /usr/local/bin

      rm -fv "$tar"
      ;;
    *)
      log error "ERROR: Your platform is not supported"
      return 1
      ;;
  esac
}

result() {
  local name="$1"
  if exists $name; then
    log success "$name is successfully installed!"
  else
    log error "Failed to install $name"
  fi
}

## Entry Point
detect_platform
set_versions

if exists zsh; then
  log info "Zsh is already exists"
else
  install_zsh
  result zsh
fi

if exists rbenv; then
  log info "rbenv is already exists"
else
  install_rbenv
  log info "rbenv is deployed, Re-Login to apply it."
fi

if exists fzf; then
  log info "fzf is already exists"
else
  install_fzf
  log info "fzf is deployed, Re-Login to apply it."
fi

if exists go; then
  log info "go is already exists"
else
  install_go
  result go
fi

if exists ghq; then
  log info "ghq is already exists"
else
  go get github.com/motemen/ghq
  result ghq
fi

if [ "$PLATFORM" = "osx" ]; then
  if exists brew; then
    log info "brew is already exists"
  else
    install_brew
    result brew
  fi

  if exists brew; then
    brew tap homebrew/versions
    brew tap caskroom/homebrew-versions

    brew install git go openssl readline reattach-to-user-namespace tmux vim
    brew cask install dropbox firefox-ja google-chrome karabiner keepassx night-owl slate totalterminal
  fi
fi
