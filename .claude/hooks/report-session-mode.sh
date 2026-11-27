# report-session の trigger hook が source する。提案で止めるか自動実行させるかを決める。
#
# Claude Code では自動実行させ、Codex では提案に留める。Codex での自動実行は確かめていない
# （自動実行の注入文は Claude Code の Skill ツールを前提に書いてある）。発火も少なく、
# 2026-10〜11 の Codex Desktop のセッション 23 件で 5 件だった。
#
# コンテキスト残量は見ない。2026-11 までは残量が 50% を切ると提案に留めていた。report-session は
# 会話履歴を継承する fork で動くので、残量が少ないと fork が上限に届く、という理由だった。
# 外したのは次の 2 つが分かったため:
#   - fork が足す量は小さい。レポートを書いた fork の記録 78 件で、中央値 2.8 万、最大 8 万トークン。
#     使用量が 79 万〜90 万トークンの状態から始まった 4 件も、compaction なしで書き終えている
#   - 提案に留めても fork が上限に届く危険は減らない。ユーザーが承認すれば、同じ fork が
#     同じ残量から走る
#
# このセッションで起動済みかも見ない。2 回目以降の起動で更新か分割かをユーザーに聞くかどうかは
# skill が決めることで、hook が先回りして止めると skill 側の決め方を変えても効かなくなる

# 引数: hook の入力 JSON。stdout に auto か suggest を出す。
# turn_id があれば Codex とみなす。Codex の入力スキーマでは UserPromptSubmit と PostToolUse の
# 必須項目で（openai/codex の rust-v0.156.1 と main の codex-rs/hooks/schema/generated）、
# Claude Code の入力には無い（2.1.332 の headless 実行で、hook に入力を書き出させて確認）
report_session_mode() {
  if printf '%s' "$1" | jq -e 'has("turn_id")' >/dev/null 2>&1; then
    echo suggest
  else
    echo auto
  fi
}

# hook は区切りの「候補」を文字列で拾うだけで、本当に区切りかの判断は会話全体を持つモデルに任せる。
# 起動済みのセッションでも自動にするので、観点 2 を前回の起動より後の分に限らないと、
# 区切りの候補が来るたびに同じ内容で起動することになる。
# $1: 区切りの候補の説明 / $2: 本当に区切りかを確かめる観点
report_session_auto_context() {
  cat <<EOF
[report-session 自動トリガー / 自動実行]
$1
次の 2 点を自分で評価せよ。

1. 本当に作業の区切りか。$2作業がまだ続く見込みなら区切りではない（後の区切りに回す）。
2. このセッションに「後から参照する価値のある学び・調査結果・設計判断」が蓄積されているか。このセッションで report-session を起動済みなら、前回の起動より後に蓄積された分だけで判断する。

- 両方を満たす場合は、ユーザーに確認せず Skill ツールで report-session を起動する。ユーザーは、この自動実行を hook の設定で許可済みである。応答の最後に、バックグラウンドでレポートを作成中である旨を一行添える。
- どちらかを満たさなければ、起動しない（何もしない。この判断に触れる必要もない）。
EOF
}

report_session_suggest_context() {
  cat <<EOF
[report-session 自動トリガー]
$1
次の 2 点を自分で評価せよ。

1. 本当に作業の区切りか。$2作業がまだ続く見込みなら区切りではない（後の区切りに回す）。
2. このセッションに「後から参照する価値のある学び・調査結果・設計判断」が蓄積されているか。このセッションで report-session を起動済みなら、前回の起動より後に蓄積された分だけで判断する。

- 両方を満たす場合のみ、通常の応答の最後に一行だけ「このセッションの学びを /report-session でまとめておきますか？」と提案する。ユーザーが承認したら実行する。
- どちらかを満たさなければ、提案しない（何もしない）。
- すでにこの会話で同じ提案をしていて未応答なら、繰り返さない。
EOF
}

# 引数: hook の入力 JSON / hookEventName / 区切りの候補の説明 / 確かめる観点
report_session_emit() {
  local context
  if [[ "$(report_session_mode "$1")" == auto ]]; then
    context="$(report_session_auto_context "$3" "$4")"
  else
    context="$(report_session_suggest_context "$3" "$4")"
  fi
  jq -nc --arg event "$2" --arg ctx "$context" \
    '{hookSpecificOutput: {hookEventName: $event, additionalContext: $ctx}}'
}
