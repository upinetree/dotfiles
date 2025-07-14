set -u

. ./scripts/lib.sh

declare -A DOTFILE_MAPS
declare DOTFILE_DIR="~/.dotfiles/"

init() {
  detect_platform
  listup_dotfiles
}

run() {
  make_base_dirs
  unlink_all
  link_all
}

make_base_dirs() {
  mkdir ~/.vim
  mkdir ~/.zsh
  mkdir ~/bin
  mkdir -p ~/.config/nvim
  mkdir -p ~/.config/yabai
  mkdir -p ~/.config/skhd
  mkdir -p ~/.config/mise
  mkdir -p ~/.config/alacritty
  mkdir -p ~/.claude
}

unlink_all() {
  for src in "${!DOTFILE_MAPS[@]}"; do
    dst="${DOTFILE_MAPS[$src]}"
    log "unlink $dst"
    eval "unlink $dst"
  done
}

link_all() {
  for src in "${!DOTFILE_MAPS[@]}"; do
    dst="${DOTFILE_MAPS[$src]}"
    log "ln -s $DOTFILE_DIR$src $dst"
    eval "ln -s $DOTFILE_DIR$src $dst"
  done
}

listup_dotfiles() {
  # src (repo root) => dst
  DOTFILE_MAPS=(
    [".gemrc"]="~/.gemrc"
    [".gitconfig"]="~/.gitconfig"
    [".gitignore"]="~/.gitignore"
    [".ripgreprc"]="~/.ripgreprc"
    [".tigrc"]="~/.tigrc"
    [".tmux.conf"]="~/.tmux.conf"
    [".vim/colors"]="~/.vim/colors"
    [".vimrc"]="~/.vimrc"
    [".zsh/.aliases.zsh"]="~/.zsh/.aliases.zsh"
    [".zsh/.exports.zsh"]="~/.zsh/.exports.zsh"
    [".zsh/.zplug.zsh"]="~/.zsh/.zplug.zsh"
    [".zshrc"]="~/.zshrc"
    [".config/nvim/init.vim"]="~/.config/nvim/init.vim"
    [".config/alacritty/alacritty.toml"]="~/.config/alacritty/alacritty.toml"
    [".config/mise/.config.toml"]="~/.config/mise/config.toml"
    ["default-gems"]="~/.config/mise/default-gems"
    [".claude/settings.json"]="~/.claude/settings.json"
    [".claude/commands"]="~/.claude/commands"
  )

  if [ "$PLATFORM" = "osx" ]; then
    DOTFILE_MAPS["osx/.slate"]="~/.slate"
    DOTFILE_MAPS["osx/.vimperatorrc"]="~/.vimperatorrc"
    DOTFILE_MAPS["osx/bin/git-completion.bash"]="~/bin/git-completion.bash"
    DOTFILE_MAPS[".config/skhd/skhdrc"]="~/.config/skhd/skhdrc"
    DOTFILE_MAPS[".config/yabai/yabaicmd"]="~/.config/yabai/yabaicmd"
  fi
}

echo_conditions() {
  log info "------- platform ------"
  log info "$PLATFORM"
  log info "--- target dotfiles ---"
  for src in "${!DOTFILE_MAPS[@]}"; do
    dst="${DOTFILE_MAPS[$src]}"
    log info "$DOTFILE_DIR$src -> $dst"
  done
  log info "-----------------------"
}

## Entry Point
init
echo_conditions
run
