set -u

. ./etc/scripts/lib.sh

set_versions() {
  export GO_VERSION="1.6.2"
}

install_zsh() {
  case "$PLATFORM" in
    osx)
      log info "zsh is installed in the homebrew installation phase"
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
      log info "go is installed in the homebrew installation phase"
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

install_dein() {
  curl https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh > installer.sh
  sh ./installer.sh ~/.vim/bundle
  rm -fv ./installer.sh
}

result() {
  local name="$1"
  if exists $name; then
    log success "$name is successfully installed!"
  else
    log error "Failed to install $name"
  fi
}

# ================== Entry Point
detect_platform
set_versions

# TODO: ファイルに分割するなりして整理する
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

    brew install git go openssl readline reattach-to-user-namespace tmux vim zsh
    brew cask install dropbox firefox-ja google-chrome iterm2 keepassx licecap skitch slate
  fi
fi

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
  log success "rbenv is deployed, Re-Login to apply it."
fi

if exists fzf; then
  log info "fzf is already exists"
else
  install_fzf
  log success "fzf is deployed, Re-Login to apply it."
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

if [ -d ~/.vim/bundle ]; then
  log info "dein.vim is already exists"
else
  install_dein
  log success "dein.vim is installed. Launch vim and execute ':call dein#install()' to install plugins"
fi
