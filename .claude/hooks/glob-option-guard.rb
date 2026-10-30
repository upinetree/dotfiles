#!/usr/bin/env ruby
# frozen_string_literal: true

# PreToolUse(Bash) hook: `--include=*.md` のような、引用符なしの glob を値に持つオプションを止める。
#
# 背景: zsh は語全体をファイル名展開にかけ、一致が無いと `no matches found` でコマンドごと落とす。
# CLAUDE.md の「Bash コマンド実行の作法」に禁止を置いた 2026-10-06 以降も 3 セッションで再発したため
# （learning-review 第 5 回）、no-clobber-redirect.rb と同じく機械的なゲートで止める。
#
# 対象は `--opt=値` の形だけ。`--` で始まる語はファイル名に一致しないので、値に glob 文字があれば
# 必ず落ちる。`find -name *.rb` のような別の語の glob は、一致するファイルがあれば通ってしまい
# 判定できないので対象外。
#
# 入力 : stdin に PreToolUse の JSON（.tool_input.command を使う）
# 出力 : 該当時のみ permissionDecision=deny を JSON で stdout。それ以外は無出力 exit 0。

require "json"

# 引用符・heredoc 本文・バックスラッシュでエスケープした文字は展開されないので落とす
def strip_quoted(cmd)
  cmd
    .gsub(/<<-?'?"?(\w+)'?"?.*?^\1$/m, " ")
    .gsub(/'[^']*'/, "''")
    .gsub(/"[^"]*"/, '""')
    .gsub(/\\./, "")
end

def glob_options(cmd)
  cmd.scan(/(?:^|\s)(--[\w-]+=[^\s;|&()<>]*[*?\[][^\s;|&()<>]*)/).flatten
end

begin
  data = JSON.parse($stdin.read.force_encoding(Encoding::UTF_8).scrub)
  cmd = data.dig("tool_input", "command").to_s
  exit 0 if cmd.empty?

  hits = glob_options(strip_quoted(cmd))
  exit 0 if hits.empty?

  reason = <<~REASON
    引用符なしの glob を値に持つオプションを検出した（#{hits.uniq.join(", ")}）。
    zsh は語全体をファイル名展開にかけ、一致が無いと `no matches found` でコマンドごと落とす。

    値を引用符で囲んで実行し直す（例: `--include='*.md'`）。
  REASON

  puts JSON.generate(
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: reason
    }
  )
rescue
  # hook 自身の失敗でツール実行を止めない
  nil
end
