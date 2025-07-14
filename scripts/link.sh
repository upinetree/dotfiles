set -u

. ./scripts/lib.sh

declare DOTFILE_DIR="~/.dotfiles/"
declare -A DOTFILE_MAPS
declare -A OBSOLETED_LIST

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

  for src in "${!OBSOLETED_LIST[@]}"; do
    dst="${OBSOLETED_LIST[$src]}"
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
    DOTFILE_MAPS["osx/bin/git-completion.bash"]="~/bin/git-completion.bash"
  fi

  OBSOLETED_LIST=(
    ["osx/.slate"]="~/.slate"
    ["osx/.vimperatorrc"]="~/.vimperatorrc"
    [".config/skhd/skhdrc"]="~/.config/skhd/skhdrc"
    [".config/yabai/yabaicmd"]="~/.config/yabai/yabaicmd"
  )
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
