# 共通（macOS / Linux）
brew "bat"
brew "carapace"
brew "ctags"
brew "gh"
brew "git"
brew "git-delta"
brew "ripgrep"

if OS.mac?
  brew "coreutils"
  brew "direnv"
  brew "ghq"
  brew "gnu-sed"
  brew "jq"
  brew "mise"
  brew "openssl"
  brew "prettier"
  brew "readline"
  brew "source-highlight"
  brew "tig"
  brew "tree"
  brew "vim"
  brew "watch"
  brew "zellij"
  brew "zsh"

  cask "1password-cli"
  cask "alacritty"
  cask "alt-tab"
  cask "bartender"
  cask "deepl"
  cask "docker"
  cask "font-myrica"
  cask "google-cloud-sdk"
  cask "kap"
  cask "karabiner-elements"
  cask "keepassxc"
  cask "maccy"
  cask "meetingbar"

  # TODO: replace yabai/skhd with an other tool
  # 導入時は install 後に brew services start yabai / skhd も必要
  # brew "koekeishiya/formulae/yabai"
  # brew "koekeishiya/formulae/skhd", args: ["HEAD"] # https://github.com/koekeishiya/skhd/issues/206
end

if OS.linux?
  brew "neovim"
end
