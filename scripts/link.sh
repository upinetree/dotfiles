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
  mkdir -p ~/.claude/skills
  mkdir -p ~/.agents/skills
  mkdir -p ~/.codex
}

unlink_all() {
  for pair in "${DOTFILE_PAIRS[@]}"; do
    remove_dst "${pair#*:}"
  done

  for pair in "${OBSOLETED_PAIRS[@]}"; do
    remove_dst "${pair#*:}"
  done
}

# dst が symlink のときだけ外す。非 symlink の実体が居座っている場合は
# 黙って消さずに退避する（エージェントが symlink を実ファイルで上書きして
# しまったケースの復旧を兼ねる。内容が分岐していても失われない）
remove_dst() {
  local dst="${1/#\~/$HOME}"
  if [ -L "$dst" ]; then
    log "unlink $dst"
    unlink "$dst"
  elif [ -e "$dst" ]; then
    local backup="$dst.bak.$(date +%Y%m%d%H%M%S)"
    log warn "$dst is not a symlink. Moving it to $backup"
    mv "$dst" "$backup"
  fi
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
    ".claude/hooks:~/.claude/hooks"
    ".claude/CLAUDE.md:~/.claude/CLAUDE.md"
    # Codex は AGENTS.md を読むが、内容はグローバル CLAUDE.md と共有する（二重管理を避ける）
    ".claude/CLAUDE.md:~/.codex/AGENTS.md"
    # hooks.json のコマンドは $HOME/.claude/hooks/ を参照するので hooks スクリプト自体の codex 向け link は不要
    ".codex/hooks.json:~/.codex/hooks.json"
  )

  if [ "$PLATFORM" = "osx" ]; then
    DOTFILE_PAIRS+=("osx/bin/git-completion.bash:~/bin/git-completion.bash")
  fi

  # skills の正本はクロスエージェント標準の .agents/skills に置く。
  # ただし Claude Code は ~/.claude/skills しか読まない（2026-09 に claude -p で実測。
  # ~/.agents/skills 直読みはしない）ため、~/.claude/skills にも橋渡し link を張る。
  # 機械ローカルに直接置かれた skill には触れない（repo 由来の名前だけを link する）
  for skill_dir in .agents/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    DOTFILE_PAIRS+=(".agents/skills/$skill_name:~/.agents/skills/$skill_name")
    DOTFILE_PAIRS+=(".agents/skills/$skill_name:~/.claude/skills/$skill_name")
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
