#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "report_store"
Encoding.default_external = Encoding::UTF_8
ARGV.map! { _1.dup.force_encoding(Encoding::UTF_8) }

begin
  ReportStore.link_daily(Obsidian.new, ARGV.fetch(0))
  puts "OK: daily note link"
rescue Obsidian::Error, SystemCallError, IndexError => e
  warn "FAIL: #{e.message}"
  exit 1
end
