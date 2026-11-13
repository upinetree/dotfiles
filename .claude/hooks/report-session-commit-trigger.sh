#!/usr/bin/env bash
#
# PostToolUse(Bash) hook: git commit / push を区切りの候補として report-session の判断を促す。
#
# hook はタイミングを知らせるだけで、本当に区切りか・学びがあるかは会話全体を持つモデルが判断する
# （判断の観点と、提案か自動実行かの分岐は report-session-mode.sh）。
#
# 入力 : stdin に PostToolUse の JSON（.tool_input.command を使う）
# 出力 : 一致時のみ additionalContext を JSON で stdout。それ以外は無出力 exit 0。

set -euo pipefail

# GUI 起動(Claude Desktop 等)では Homebrew が PATH に入らず jq が見つからないため補正
PATH="/opt/homebrew/bin:$PATH"

input="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"

# コマンドとして実行された git commit / push だけを拾う（行頭か ; & | の直後。git -C <path> も含む）。
# 文字列のどこかに現れるだけで拾うと、grep の引数やテストデータでも発火し、自動実行まで進んでしまう
if ! printf '%s' "$cmd" | grep -qE '(^|[;&|])[[:space:]]*git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+(commit|push)([[:space:]]|$)'; then
  exit 0
fi
if printf '%s' "$cmd" | grep -qE -- '--dry-run'; then
  exit 0
fi

source "$(dirname "${BASH_SOURCE[0]}")/report-session-mode.sh"
report_session_emit "$input" PostToolUse \
  'git commit / push らしきコマンドが実行された。' \
  'コマンドが成功し、ひとまとまりの作業を出荷したところか（複数コミットに分ける作業の途中ではないか）を確かめる。'
exit 0
