#!/usr/bin/env bash
#
# UserPromptSubmit hook: report-session の自動提案トリガー
#
# 役割（=「いつ判断させるか」の安いゲートだけを担う。区切りか・学びがあるかの判定はしない）:
#   1. ユーザー発言に満足/完了シグナルが含まれるか
#   2. 会話が一定長を超えているか（1〜2ターンの短い会話は除外）
#   両方を満たしたときだけ、Claude に判断を促す追加コンテキストを注入する。
#   判断の観点と、提案か自動実行かの分岐は report-session-mode.sh。
#
# 入力 : stdin に UserPromptSubmit の JSON（.prompt / .transcript_path を使う）
# 出力 : 条件一致時のみ additionalContext を JSON で stdout に出す。それ以外は無出力 exit 0。

set -euo pipefail

# GUI 起動(Claude Desktop 等)では Homebrew が PATH に入らず jq が見つからないため補正
PATH="/opt/homebrew/bin:$PATH"

# --- 設定 -------------------------------------------------------------------
# 会話長ゲート: transcript(.jsonl) の行数がこれ未満なら発火しない
MIN_TRANSCRIPT_LINES="${REPORT_SESSION_MIN_LINES:-12}"

# 満足/完了シグナル（大文字小文字無視）。区切りかどうかはモデルが判断するので広めに拾ってよい
# （誤って拾っても注入文の数百トークンで済む）。
# 後半の、作業を閉じる行動（マージ・別セッションへの移行・片付け・close）は、2026-11 に過去
# 137 セッションの終わり際の発言を調べて足した。お礼や満足の語は終わり際にほとんど出ず、
# 終わり際の発言の多くはこうした締めの指示や報告だった
SIGNAL_REGEX='ありがとう|ありがと|助かっ|助かる|サンキュー|thank|完璧|かんぺき|ばっちり|バッチリ|解決|直った|治った|動いた|うまくいっ|うまく行っ|いい感じ|良い感じ|よさそう|良さそう|完了|終わった|終わりました|できた|出来た|期待通り|思った通り|問題なさ|問題ない|バッチ|perfect|完成|マージし|merged|別セッション|片付け|片づけ|かたづけ|close ?して|クローズ'
# ----------------------------------------------------------------------------

input="$(cat)"

# jq が無い環境でも落ちないようフォールバック
if command -v jq >/dev/null 2>&1; then
  prompt="$(printf '%s' "$input" | jq -r '.prompt // ""')"
  transcript="$(printf '%s' "$input" | jq -r '.transcript_path // ""')"
else
  exit 0
fi

# --- ゲート0: 人の発言でないもの ---------------------------------------------
# UserPromptSubmit は通知・定期実行・別セッションからのメッセージでも発火し、その文面
# （"completed" や「完了」）がシグナルに当たる。hook の入力に出どころの項目は無い
# （claude 2.1.323 で確認）ので、過去の transcript で人以外が送っていた書き出しで見分ける
case "${prompt#"${prompt%%[![:space:]]*}"}" in
  '<task-notification'* | '<scheduled-task'* | 'Another Claude session sent a message:'*) exit 0 ;;
esac

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
source "$(dirname "${BASH_SOURCE[0]}")/report-session-mode.sh"
report_session_emit "$input" UserPromptSubmit \
  'ユーザーの直近の発言に満足/完了のシグナルらしき語が含まれ、会話も十分に積み上がっている。' \
  'その発言が作業全体の完了や満足を示しているか（途中経過への相づちや、次の依頼の前置きではないか）を確かめる。'
exit 0
