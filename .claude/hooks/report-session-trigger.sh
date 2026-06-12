#!/usr/bin/env bash
#
# UserPromptSubmit hook: report-session の自動提案トリガー
#
# 役割（=「いつ判断させるか」の安いゲートだけを担う。学びの有無の判定はしない）:
#   1. ユーザー発言に満足/完了シグナルが含まれるか
#   2. 会話が一定長を超えているか（1〜2ターンの短い会話は除外）
#   両方を満たしたときだけ、Claude に「学びがあれば /report-session を一行で提案せよ」
#   という追加コンテキストを注入する。最終的に書く価値があるかはモデルが判断する。
#
# 入力 : stdin に UserPromptSubmit の JSON（.prompt / .transcript_path を使う）
# 出力 : 条件一致時のみ additionalContext を JSON で stdout に出す。それ以外は無出力 exit 0。

set -euo pipefail

# --- 設定 -------------------------------------------------------------------
# 会話長ゲート: transcript(.jsonl) の行数がこれ未満なら発火しない
MIN_TRANSCRIPT_LINES="${REPORT_SESSION_MIN_LINES:-12}"

# 満足/完了シグナル（大文字小文字無視）。誤爆は「一行提案」で済むため、
# 明確な肯定・完了表現を中心に拾う。
SIGNAL_REGEX='ありがとう|ありがと|助かっ|助かる|サンキュー|thank|完璧|かんぺき|ばっちり|バッチリ|解決|直った|治った|動いた|うまくいっ|うまく行っ|いい感じ|良い感じ|よさそう|良さそう|完了|終わった|終わりました|できた|出来た|期待通り|思った通り|問題なさ|問題ない|バッチ|perfect|完成'
# ----------------------------------------------------------------------------

input="$(cat)"

# jq が無い環境でも落ちないようフォールバック
if command -v jq >/dev/null 2>&1; then
  prompt="$(printf '%s' "$input" | jq -r '.prompt // ""')"
  transcript="$(printf '%s' "$input" | jq -r '.transcript_path // ""')"
else
  exit 0
fi

# --- ゲート1: 満足/完了シグナル ---------------------------------------------
if ! printf '%s' "$prompt" | grep -iqE "$SIGNAL_REGEX"; then
  exit 0
fi

# --- ゲート2: 会話長 ---------------------------------------------------------
lines=0
if [[ -n "$transcript" && -f "$transcript" ]]; then
  lines="$(wc -l < "$transcript" | tr -d ' ')"
fi
if (( lines < MIN_TRANSCRIPT_LINES )); then
  exit 0
fi

# --- コンテキスト注入 --------------------------------------------------------
read -r -d '' CONTEXT <<'EOF' || true
[report-session 自動トリガー]
ユーザーの直近の発言に満足/完了のシグナルが含まれ、かつ会話が十分に積み上がっている。
このセッションに「後から参照する価値のある学び・調査結果・設計判断」が実際に蓄積されているか自分で評価せよ。

- 価値のある学びがある場合のみ、通常の応答の最後に一行だけ「このセッションの学びを /report-session でまとめておきますか？」と提案する。ユーザーが承認したら実行する。
- 単なる作業完了で記録に値する知見がなければ、提案しない（何もしない）。
- すでにこの会話で同じ提案をしていて未応答なら、繰り返さない。
EOF

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg ctx "$CONTEXT" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
fi
exit 0
