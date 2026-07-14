#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

begin
  # Claude Desktop 起動の hook 環境には LANG/LC_* が無く default external が
  # US-ASCII になるため、UTF-8 を明示しないと日本語を含む入力の parse で落ちる
  data = JSON.parse($stdin.read.force_encoding(Encoding::UTF_8).scrub)
  exit 0 if File.exist?("/tmp/.claude-skip-format")
  file = data.dig("tool_input", "file_path").to_s
  exit 0 if file.empty? || file.start_with?("-")
  exit 0 unless file.match?(/\.(rb|rake)\z/)

  if system("bundle", "show", "standard", out: File::NULL, err: File::NULL)
    system("bundle", "exec", "standardrb", "--fix", "--", file)
  else
    system("bundle", "exec", "rubocop", "--force-exclusion", "-A", "--", file)
  end
rescue
  nil
end
