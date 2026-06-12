#!/usr/bin/env bash
#
# PostToolUse(Bash) hook: git commit / push を「完了プロキシ」として
# report-session の自動提案トリガーにする。
#
# 役割（=「成果の区切り」を確実に拾う安いゲート。学びの有無は判定しない）:
#   実行された Bash コマンドが git commit / git push なら、Claude に
#   「作業が1単位出荷された。学びがあれば /report-session を一行で提案せよ」
#   という追加コンテキストを注入する。書く価値があるかはモデルが最終判断する。
#
# 入力 : stdin に PostToolUse の JSON（.tool_input.command を使う）
# 出力 : 一致時のみ additionalContext を JSON で stdout。それ以外は無出力 exit 0。

set -euo pipefail

input="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"

# git commit / git push を検出（--dry-run や log/diff などは拾わない）
if ! printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+(commit|push)\b'; then
  exit 0
fi
if printf '%s' "$cmd" | grep -qE -- '--dry-run'; then
  exit 0
fi

read -r -d '' CONTEXT <<'EOF' || true
[report-session 自動トリガー / 完了プロキシ]
git commit / push が実行された。作業が1単位、出荷された区切りである。
このセッションに「後から参照する価値のある学び・調査結果・設計判断」が蓄積されているか自分で評価せよ。

- 価値のある学びがある場合のみ、応答の最後に一行だけ「このセッションの学びを /report-session でまとめておきますか？」と提案する。ユーザーが承認したら実行する。
- 単純な変更で記録に値する知見がなければ、提案しない（何もしない）。
- すでにこの会話で同じ提案をしていて未応答なら、繰り返さない。
EOF

jq -nc --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
exit 0
