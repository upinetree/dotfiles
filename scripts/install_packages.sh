set -u

. ./scripts/lib.sh

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

# DEPRECATED: すでに呼ばれなくなっているが、一部 mise に移行しきれていない部分の処遇が決まっていないので残している
install_rbenv() {
  git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
  git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
  git clone https://github.com/rbenv/rbenv-default-gems.git ~/.rbenv/plugins/rbenv-default-gems
  git clone https://github.com/amatsuda/gem-src.git ~/.rbenv/plugins/gem-src # mise 移行メモ: ruby install 時のグローバルな hook が未提供 https://github.com/jdx/mise/issues/4748
  git clone https://github.com/rkh/rbenv-update.git ~/.rbenv/plugins/rbenv-update
  git clone https://github.com/tpope/rbenv-ctags.git ~/.rbenv/plugins/rbenv-ctags # mise 移行メモ: gem ctags 単体では bundler hook がないので若干不便 (必要に応じて手動実行でも運用上は十分そうではある)

  ln -s ~/.dotfiles/default-gems ~/.rbenv/default-gems
}

install_fzf() {
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  bash ~/.fzf/install
}

install_brew() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

install_dein() {
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/Shougo/dein-installer.vim/master/installer.sh)"
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

# Homebrew cask は upstream が公証しないため 2026-09-01 に disabled になった。cask と同じ DMG を同じ sha256 で固定して取る
# https://github.com/alacritty/alacritty/issues/8749
ALACRITTY_VERSION="0.17.0"
ALACRITTY_DMG_SHA256="ad8d7de35fb38e43184776cac6dfee05ca325caa0b6639a06a55e54e4b026620"

installed_alacritty_version() {
  defaults read /Applications/Alacritty.app/Contents/Info CFBundleShortVersionString 2>/dev/null
}

install_alacritty() {
  local base="https://github.com/alacritty/alacritty/releases/download/v${ALACRITTY_VERSION}"
  local work
  local dmg

  # cask が残ったまま置き換えると、後の brew uninstall --cask が新しい版を消す
  if brew list --cask alacritty &>/dev/null; then
    log error "alacritty cask is still installed. Run \`brew uninstall --cask alacritty\` first"
    return 1
  fi

  work="$(mktemp -d)"
  dmg="$work/Alacritty-v${ALACRITTY_VERSION}.dmg"
  curl -fsSLo "$dmg" "$base/Alacritty-v${ALACRITTY_VERSION}.dmg" || return 1
  echo "${ALACRITTY_DMG_SHA256}  ${dmg}" | shasum -a 256 -c - || return 1

  # ditto は既存の bundle に上書きマージして旧版のファイルを残すので、旧版はよけてから置く
  if [ -d /Applications/Alacritty.app ]; then
    mv /Applications/Alacritty.app "$work/"
    log info "Previous Alacritty.app is moved to $work"
  fi

  mkdir "$work/mnt"
  hdiutil attach -nobrowse -readonly -mountpoint "$work/mnt" "$dmg" >/dev/null || return 1
  ditto "$work/mnt/Alacritty.app" /Applications/Alacritty.app
  hdiutil detach "$work/mnt" >/dev/null

  # cask はアプリ内の terminfo へ symlink していた。tic で実体を置き、アプリの置き場所に依存させない
  curl -fsSLo "$work/alacritty.info" "$base/alacritty.info" || return 1
  tic -xe alacritty,alacritty-direct "$work/alacritty.info"
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

if [ "$PLATFORM" = "osx" ] || [ "$PLATFORM" = "linux" ]; then
  if exists brew; then
    log info "brew is already exists"
  else
    install_brew
    result brew
  fi

  if exists brew; then
    brew bundle install --file=./Brewfile
  else
    log error "brew command not found"
    exit 1
  fi
fi

if [ "$PLATFORM" = "osx" ]; then
  if [ "$(installed_alacritty_version)" = "$ALACRITTY_VERSION" ]; then
    log info "alacritty $ALACRITTY_VERSION is already installed"
  elif install_alacritty; then
    log success "alacritty $ALACRITTY_VERSION is successfully installed!"
  else
    log error "Failed to install alacritty"
  fi
fi

if [ "$PLATFORM" = "linux" ]; then
  if [ -n "${WSLENV:-}" ]; then
    if exists win32yank.exe; then
      log info "win32yank is already exists"
    else
      curl -sLo/tmp/win32yank.zip https://github.com/equalsraf/win32yank/releases/download/v0.0.4/win32yank-x64.zip
      unzip -p /tmp/win32yank.zip win32yank.exe >/tmp/win32yank.exe
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

# if exists rbenv; then
#   log info "rbenv is already exists"
# else
#   install_rbenv
#   log success "rbenv is deployed, Re-Login to apply it."
# fi

if exists mise; then
  mise install
fi

if exists fzf; then
  log info "fzf is already exists"
else
  install_fzf
  log success "fzf is deployed, Re-Login to apply it."
fi

# TODO: fix dein installation and settings
# if [ -d ~/.cache/dein ]; then
#   log info "dein.vim is already exists"
# else
#   install_dein
#   log success "dein.vim is installed. Launch vim and execute ':call dein#install()' to install plugins"
# fi

log success "Finished. Re-Login to zsh to complete."
log success "Manual installation required: e.g.) firefox google-chrome slack dash, from the web or AppStore"
