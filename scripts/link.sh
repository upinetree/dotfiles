set -u

. ./scripts/lib.sh

declare DOTFILE_DIR="~/.dotfiles/"
declare -a DOTFILE_PAIRS
declare -a OBSOLETED_PAIRS

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
  mkdir -p ~/.claude/skills
}

unlink_all() {
  for pair in "${DOTFILE_PAIRS[@]}"; do
    dst="${pair#*:}"
    log "unlink $dst"
    eval "unlink $dst"
  done

  for pair in "${OBSOLETED_PAIRS[@]}"; do
    dst="${pair#*:}"
    log "unlink $dst"
    eval "unlink $dst"
  done
}

link_all() {
  for pair in "${DOTFILE_PAIRS[@]}"; do
    src="${pair%%:*}"
    dst="${pair#*:}"
    log "ln -s $DOTFILE_DIR$src $dst"
    eval "ln -s $DOTFILE_DIR$src $dst"
  done
}

listup_dotfiles() {
  # src (repo root):dst
  DOTFILE_PAIRS=(
    ".gemrc:~/.gemrc"
    ".gitconfig:~/.gitconfig"
    ".gitignore:~/.gitignore"
    ".ripgreprc:~/.ripgreprc"
    ".tigrc:~/.tigrc"
    ".tmux.conf:~/.tmux.conf"
    ".vim/colors:~/.vim/colors"
    ".vimrc:~/.vimrc"
    ".zsh/.aliases.zsh:~/.zsh/.aliases.zsh"
    ".zsh/.exports.zsh:~/.zsh/.exports.zsh"
    ".zsh/.zplug.zsh:~/.zsh/.zplug.zsh"
    ".zshrc:~/.zshrc"
    ".config/nvim/init.vim:~/.config/nvim/init.vim"
    ".config/alacritty/alacritty.toml:~/.config/alacritty/alacritty.toml"
    ".config/mise/.config.toml:~/.config/mise/config.toml"
    "default-gems:~/.config/mise/default-gems"
    ".claude/settings.json:~/.claude/settings.json"
  )

  if [ "$PLATFORM" = "osx" ]; then
    DOTFILE_PAIRS+=("osx/bin/git-completion.bash:~/bin/git-completion.bash")
  fi

  for skill_dir in .claude/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    DOTFILE_PAIRS+=(".claude/skills/$skill_name:~/.claude/skills/$skill_name")
  done

  OBSOLETED_PAIRS=(
    ".config/skhd/skhdrc:~/.config/skhd/skhdrc"
    ".config/yabai/yabaicmd:~/.config/yabai/yabaicmd"
  )
}

echo_conditions() {
  log info "------- platform ------"
  log info "$PLATFORM"
  log info "--- target dotfiles ---"
  for pair in "${DOTFILE_PAIRS[@]}"; do
    src="${pair%%:*}"
    dst="${pair#*:}"
    log info "$DOTFILE_DIR$src -> $dst"
  done
  log info "-----------------------"
}

## Entry Point
init
echo_conditions
run
