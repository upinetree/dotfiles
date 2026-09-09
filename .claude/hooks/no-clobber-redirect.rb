#!/usr/bin/env ruby
# frozen_string_literal: true

# PreToolUse(Bash) hook: ファイルへの `>` 上書きリダイレクトを止める。
#
# 背景: zsh の noclobber 下で既存ファイルへの `>` は silent fail し、古い内容が
# 残ったまま後続コマンドが成功して「検証成功」に見える。CLAUDE.md に禁止ルールを
# 置いた後も 3 セッションで再発したため（gh pr edit --body-file に古いファイルを
# 渡した事例を含む）、注意力でなく機械的なゲートで止める。
#
# 対象外: `>>` 追記、`>|` 明示 clobber、`2>`/`&>`/`>&` の fd 系、/dev/* への破棄。
# これらは silent fail しないか、上書き事故の対象にならない。
#
# 入力 : stdin に PreToolUse の JSON（.tool_input.command を使う）
# 出力 : 該当時のみ permissionDecision=deny を JSON で stdout。それ以外は無出力 exit 0。

require "json"

# 引用符・heredoc 本文の中身は解析対象から落とす（文中の `->` や `>` の誤検知を防ぐ）
def strip_quoted(cmd)
  cmd
    .gsub(/<<-?'?"?(\w+)'?"?.*?^\1$/m, " ")  # heredoc 本文
    .gsub(/'[^']*'/, "''")
    .gsub(/"[^"]*"/, '""')
end

# fd 指定・追記・明示 clobber・プロセス置換を潰したうえで、素の `>` の直後の語を拾う
def clobber_targets(cmd)
  scan = cmd
    .gsub(/[0-9]*>>/, " APPEND ")   # >> と 2>>
    .gsub(/>\|/, " CLOBBER_OK ")    # >| は許可済み
    .gsub(/[0-9]*>&[0-9-]*/, " FD ") # 2>&1, >&2
    .gsub(/&>>?/, " FD ")            # &> / &>>
    .gsub(/>\(/, " PROCSUB ")        # >(...) プロセス置換
    .gsub(/[0-9]+>/, " FD ")         # 2> file
  scan.scan(%r{>\s*([^\s;|&()<>]+)}).flatten
end

def actual_file?(target)
  return false if target.empty?
  return false if target.start_with?("/dev/")
  return false if target.start_with?("$") && !target.include?("/") # 変数のみは判定不能

  true
end

begin
  data = JSON.parse($stdin.read.force_encoding(Encoding::UTF_8).scrub)
  cmd = data.dig("tool_input", "command").to_s
  exit 0 if cmd.empty?

  targets = clobber_targets(strip_quoted(cmd)).select { |t| actual_file?(t) }
  exit 0 if targets.empty?

  reason = <<~REASON
    ファイルへの `>` 上書きリダイレクトを検出した（対象: #{targets.uniq.join(", ")}）。
    zsh の noclobber で silent fail し、古い内容が残ったまま「検証成功」に見える事故が再発している。

    次のいずれかに切り替える:
      - ファイル生成・上書き → Write ツール
      - スクリプトで組む → python3 の open() / ruby の File.write
      - 追記でよい → `>>`
      - どうしてもシェルで上書きする → `>|` を使い、直後に内容を検証する
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
