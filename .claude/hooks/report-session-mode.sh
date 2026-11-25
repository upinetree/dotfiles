# report-session の trigger hook が source する。提案で止めるか自動実行させるかを決める。
#
# report-session は会話履歴を継承する fork で動き、今のコンテキストを抱えたままレポートを書くので、
# 残量が少ないときに自動で走らせると fork 側が上限に届く。
#
# hook の入力にはコンテキスト残量が無い（statusline の入力にだけある。claude 2.1.323 で確認）ため、
# 残量は次のどちらかから取る:
#   - statusline-command.sh が session ごとに書き出す context_window（残量と窓の大きさの実測）
#   - デスクトップアプリのセッションでは transcript の usage。デスクトップでは残量のファイルが
#     書かれず（2026-11 に直近 3 日のセッションで確認: デスクトップ 31 件中 0 件、CLI 5 件中 5 件）、
#     導入から 2 週間の発火 466 件が一度も自動にならなかった。窓の大きさは transcript に無いので
#     REPORT_SESSION_CONTEXT_WINDOW を仮定する。実際の窓がこれより小さいセッションでは残量を
#     多く見積もるので、そういうモデルを使うなら値を下げる
#
# 次のどれかなら提案に留める（ユーザーの承認を待つ）:
#   - 残量が分からない（残量のファイルも無く、デスクトップでもない。Codex や headless 実行）
#   - 残量が REPORT_SESSION_AUTO_MIN_REMAINING（%）未満
#
# このセッションで起動済みかは見ない。2 回目以降の起動で更新か分割かをユーザーに聞くかどうかは
# skill が決めることで、hook が先回りして止めると skill 側の決め方を変えても効かなくなる

REPORT_SESSION_CTX_DIR="${REPORT_SESSION_CTX_DIR:-$HOME/.cache/claude-statusline}"
REPORT_SESSION_AUTO_MIN_REMAINING="${REPORT_SESSION_AUTO_MIN_REMAINING:-50}"
REPORT_SESSION_CONTEXT_WINDOW="${REPORT_SESSION_CONTEXT_WINDOW:-1000000}"

# 引数: transcript のパス。デスクトップアプリのセッションなら残量（%）を出し、それ以外は何も出さない。
# 次のリクエストの入力は直前の応答の入力（cache を含む）とほぼ同じ大きさなので、最後の応答の
# usage を今の使用量とみなす（statusline の current_usage と 2 セッションで突き合わせ、差は 0.5% 以内）。
# 末尾だけを読む。transcript は 100 MB を超えるものがあり、発火のたびに全体を読ませない
report_session_desktop_remaining() {
  local transcript="$1"
  [[ -n "$transcript" && -f "$transcript" ]] || return 0
  tail -n 200 "$transcript" 2>/dev/null |
    jq -Rn --argjson window "$REPORT_SESSION_CONTEXT_WINDOW" '
      [inputs
        | fromjson?
        | select(.type? == "assistant" and (.isSidechain | not))
        | {entrypoint,
           used: (.message.usage? // {}
             | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))}
        | select(.used > 0)]
      | last
      | select(. != null and .entrypoint == "claude-desktop" and $window > 0)
      | ($window - .used) * 100 / $window' 2>/dev/null || true
}

# 引数: hook の入力 JSON。stdout に auto か suggest を出す。
report_session_mode() {
  local input="$1" session_id transcript ctx_file remaining

  session_id="$(printf '%s' "$input" | jq -r '.session_id // ""')"
  transcript="$(printf '%s' "$input" | jq -r '.transcript_path // ""')"
  ctx_file="$REPORT_SESSION_CTX_DIR/$session_id.json"

  # デスクトップでは残量のファイルより transcript を優先する。CLI で始めたセッションを
  # デスクトップで続けると、CLI のときの残量がファイルに残ったまま更新されない
  remaining="$(report_session_desktop_remaining "$transcript")"
  if [[ -z "$remaining" && "$session_id" =~ ^[A-Za-z0-9_-]+$ && -f "$ctx_file" ]]; then
    remaining="$(jq -r '.remaining_percentage | numbers' "$ctx_file" 2>/dev/null || true)"
  fi

  if [[ -n "$remaining" ]] &&
    jq -e -n --argjson remaining "$remaining" --argjson min "$REPORT_SESSION_AUTO_MIN_REMAINING" \
      '$remaining >= $min' >/dev/null 2>&1; then
    echo auto
  else
    echo suggest
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
