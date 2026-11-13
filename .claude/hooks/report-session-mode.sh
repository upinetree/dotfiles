# report-session の trigger hook が source する。提案で止めるか自動実行させるかを決める。
#
# hook の入力にはコンテキスト残量が無い（statusline の入力にだけある。claude 2.1.323 で確認）ため、
# statusline-command.sh が session ごとに書き出す context_window を読む。
# report-session は会話履歴を継承する fork で動き、今のコンテキストを抱えたままレポートを書くので、
# 残量が少ないときに自動で走らせると fork 側が上限に届く。
#
# 次のどれかなら提案に留める（今までどおりユーザーの承認を待つ）:
#   - 残量のファイルが無い（statusline の無い Codex や headless 実行）
#   - 残量が REPORT_SESSION_AUTO_MIN_REMAINING（%）未満
#   - このセッションで report-session を起動済み。2 回目の起動は更新か分割かをユーザーに聞く作りなので
#     自動にしない

REPORT_SESSION_CTX_DIR="${REPORT_SESSION_CTX_DIR:-$HOME/.cache/claude-statusline}"
REPORT_SESSION_AUTO_MIN_REMAINING="${REPORT_SESSION_AUTO_MIN_REMAINING:-50}"

# 引数: hook の入力 JSON。stdout に auto か suggest を出す。
report_session_mode() {
  local input="$1" session_id transcript ctx_file

  session_id="$(printf '%s' "$input" | jq -r '.session_id // ""')"
  transcript="$(printf '%s' "$input" | jq -r '.transcript_path // ""')"
  ctx_file="$REPORT_SESSION_CTX_DIR/$session_id.json"

  if [[ ! "$session_id" =~ ^[A-Za-z0-9_-]+$ || ! -f "$ctx_file" ]]; then
    echo suggest
    return
  fi

  if ! jq -e --argjson min "$REPORT_SESSION_AUTO_MIN_REMAINING" \
    '(.remaining_percentage | type) == "number" and .remaining_percentage >= $min' \
    "$ctx_file" >/dev/null 2>&1; then
    echo suggest
    return
  fi

  # grep で絞ってから jq で実際の起動だけを見る。tool の出力や会話中に文字列が出ただけでは数えない
  if [[ -n "$transcript" && -f "$transcript" ]] &&
    grep -qF -e '"skill":"report-session"' -e '<command-name>/report-session</command-name>' "$transcript" &&
    jq -e -n '
      [inputs
        | .message.content?
        | if type == "string" then select(contains("<command-name>/report-session</command-name>"))
          elif type == "array" then .[] | select(.type? == "tool_use" and .name == "Skill" and .input.skill? == "report-session")
          else empty end]
      | length > 0' "$transcript" >/dev/null 2>&1; then
    echo suggest
    return
  fi

  echo auto
}

# hook は区切りの「候補」を文字列で拾うだけで、本当に区切りかの判断は会話全体を持つモデルに任せる。
# 自動実行では最初の 1 回しか自動にならないので、作業の途中で起動すると前半だけのレポートになる。
# $1: 区切りの候補の説明 / $2: 本当に区切りかを確かめる観点
report_session_auto_context() {
  cat <<EOF
[report-session 自動トリガー / 自動実行]
$1
次の 2 点を自分で評価せよ。

1. 本当に作業の区切りか。$2作業がまだ続く見込みなら区切りではない（後の区切りに回す）。
2. このセッションに「後から参照する価値のある学び・調査結果・設計判断」が蓄積されているか。

- 両方を満たす場合は、ユーザーに確認せず Skill ツールで report-session を起動する。ユーザーは、コンテキスト残量が十分なときの自動実行を hook の設定で許可済みである。応答の最後に、バックグラウンドでレポートを作成中である旨を一行添える。
- どちらかを満たさなければ、起動しない（何もしない。この判断に触れる必要もない）。
EOF
}

report_session_suggest_context() {
  cat <<EOF
[report-session 自動トリガー]
$1
次の 2 点を自分で評価せよ。

1. 本当に作業の区切りか。$2作業がまだ続く見込みなら区切りではない（後の区切りに回す）。
2. このセッションに「後から参照する価値のある学び・調査結果・設計判断」が蓄積されているか。

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
