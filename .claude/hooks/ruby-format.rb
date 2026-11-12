#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require_relative "format-skip"

begin
  # Claude Desktop 起動の hook 環境には LANG/LC_* が無く default external が
  # US-ASCII になるため、UTF-8 を明示しないと日本語を含む入力の parse で落ちる
  data = JSON.parse($stdin.read.force_encoding(Encoding::UTF_8).scrub)
  file = data.dig("tool_input", "file_path").to_s
  exit 0 if file.empty? || file.start_with?("-")
  ext = File.extname(file)
  exit 0 unless ext.match?(/\A\.(rb|rake)\z/)
  exit 0 if FormatSkip.skip?(file, ext)

  # このフック自体は .claude/hooks/ruby（mise が入れた最新の Ruby）で動くが、整形は作業ディレクトリの
  # Ruby と bundle で行う。PATH では最新の Ruby の bin が shim より前にあることがあり、そのまま bundle を
  # 引くと別の版の bundle になって整形が黙って止まるので、版を作業ディレクトリから選ぶ shim を呼ぶ
  shim = File.expand_path("~/.local/share/mise/shims/bundle")
  bundle = File.executable?(shim) ? shim : "bundle"
  if system(bundle, "show", "standard", out: File::NULL, err: File::NULL)
    system(bundle, "exec", "standardrb", "--fix", "--", file)
  else
    system(bundle, "exec", "rubocop", "--force-exclusion", "-A", "--", file)
  end
rescue
  nil
end
