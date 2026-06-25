#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

begin
  data = JSON.parse($stdin.read)
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
