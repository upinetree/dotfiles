set -u

. ./scripts/lib.sh

set_versions() {
  export GO_VERSION="1.16.5"
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
}

change_shell_to_zsh() {
  if [[ $SHELL =~ zsh ]]; then
    log info "Shell is already set as zsh."
    return 0
  fi

  zsh_path="$(which zsh)"

  if ! grep -xq $zsh_path /etc/shells; then
    log warn "\`$zsh_path\` should be appended in /etc/shells. Append it now:"
    echo $zsh_path | sudo tee -a /etc/shells
  fi

  log info "To change shell to $zsh_path, type your password:"
  if chsh -s "$zsh_path"; then
    log success "Changing shell to $zsh_path is successfully finished! Re-Login to apply it."
  else
    log warn "Changing shell to $zsh_path is failed"
  fi
}

install_zplug() {
  curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
}

install_rbenv() {
  git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
  git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
  git clone https://github.com/rbenv/rbenv-default-gems.git ~/.rbenv/plugins/rbenv-default-gems
  git clone https://github.com/amatsuda/gem-src.git ~/.rbenv/plugins/gem-src
  git clone https://github.com/rkh/rbenv-update.git ~/.rbenv/plugins/rbenv-update
  git clone https://github.com/tpope/rbenv-ctags.git ~/.rbenv/plugins/rbenv-ctags

  ln -s  ~/.dotfiles/.rbenv/default-gems ~/.rbenv/default-gems
}

install_fzf() {
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  bash ~/.fzf/install
}

install_brew() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
  sh ./installer.sh ~/.cache/dein
  rm -fv ./installer.sh
}

install_tmux() {
  if exists brew; then
    brew install tmux
  else
    log error "Install tmux manually : https://github.com/tmux/tmux"
  fi

  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  ~/.tmux/plugins/tpm/bin/install_plugins
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
    brew tap homebrew/cask-versions

    brew install anyenv bat coreutils ctags direnv git-delta gnu-sed git gh openssl readline ripgrep source-highlight tig tree vim watch zsh
    brew install alt-tab chromedriver dropbox iterm2 kap keepassx karabiner-elements meetingbar slate 1password/tap/1password-cli
  else
    log error "brew command not found"
    exit 1
  fi
fi

if [ "$PLATFORM" = "linux" ]; then
  if exists brew; then
    log info "brew is already exists"
  else
    install_brew
    result brew
  fi

  if exists brew; then
    brew install bat ctags git-delta ripgrep git gh nvim
  else
    log error "brew command not found"
    exit 1
  fi

  if [ -n "$WSLENV" ]; then
    if exists win32yank.exe; then
      log info "win32yank is already exists"
    else
      curl -sLo/tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/download/v0.0.4/win32yank-x64.zip
      unzip -p /tmp/win32yank.zip win32yank.exe > /tmp/win32yank.exe
      chmod +x /tmp/win32yank.exe
      sudo mv /tmp/win32yank.exe /usr/local/bin/
    fi
  fi
fi

if exists zsh; then
  log info "Zsh is already exists"
else
  install_zsh
  result zsh
fi
change_shell_to_zsh

if [ -d ~/.zplug ]; then
  log info "Zplug is already exists"
else
  install_zplug
  log success "zplug is deployed, Re-Login to apply it."
fi

if exists tmux; then
  log info "tmux is already exists"
else
  install_tmux
  result tmux
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
  go get github.com/x-motemen/ghq
  result ghq
fi

if [ -d ~/.cache/dein ]; then
  log info "dein.vim is already exists"
else
  install_dein
  log success "dein.vim is installed. Launch vim and execute ':call dein#install()' to install plugins"
fi

log success "Finished. Re-Login to zsh to complete."
log success "Manual installation required: e.g.) firefox google-chrome slack dash, from the web or AppStore"
