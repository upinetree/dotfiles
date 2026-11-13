#!/bin/sh
# Claude Code status line - inspired by pure theme (directory ~ git-branch)
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')

# Shorten home directory to ~
home="$HOME"
short_cwd=$(echo "$cwd" | sed "s|^$home|~|")

# Git branch (skip optional locks)
git_branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" -c core.hooksPath=/dev/null symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Context usage
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# hook の入力には context_window が無いので、hook が読めるよう session ごとに書き出す
# （読み手は hooks/report-session-mode.sh。置き場所を変えるときは両方そろえる）。
# 書きかけを読まれないよう一時ファイルから mv で置き換える。失敗しても表示は止めない
ctx_dir="${REPORT_SESSION_CTX_DIR:-/tmp/claude-statusline}"
session_id=$(echo "$input" | jq -r '.session_id // empty')
case "$session_id" in
  "" | *[!A-Za-z0-9_-]*) ;;
  *)
    if mkdir -p "$ctx_dir" 2>/dev/null; then
      ctx_tmp="$ctx_dir/.$session_id.$$"
      if echo "$input" | jq -c '.context_window // {}' >|"$ctx_tmp" 2>/dev/null; then
        mv -f "$ctx_tmp" "$ctx_dir/$session_id.json" 2>/dev/null
      fi
    fi
    ;;
esac

# Build status line with ANSI colors (dimmed-friendly)
# Format: ~ dir  git-branch  model  ctx:XX%
if [ -n "$git_branch" ]; then
  printf "\033[36m%s\033[0m  \033[35m%s\033[0m  \033[33m%s\033[0m" "$short_cwd" "$git_branch" "$model"
else
  printf "\033[36m%s\033[0m  \033[33m%s\033[0m" "$short_cwd" "$model"
fi

if [ -n "$used" ]; then
  printf "  \033[90mctx:%.0f%%\033[0m" "$used"
fi
