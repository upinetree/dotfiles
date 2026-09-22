#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require_relative "report_store"

Encoding.default_external = Encoding::UTF_8
# ARGV was decoded before the default external encoding changed.
ARGV.map! { _1.dup.force_encoding(Encoding::UTF_8) }

begin
  local = nil
  OptionParser.new do |parser|
    parser.on("--local DIRECTORY") { local = _1 }
  end.parse!(ARGV)
  source, target = ARGV
  raise Obsidian::Error, "Usage: save_report.rb [--local DIRECTORY] SOURCE 'TIMESTAMP TITLE'" unless ARGV.size == 2
  ReportStore.validate_target(target)
  client = Obsidian.new unless local
  root = local ? File.expand_path(local) : client.vault
  path = ReportStore.report_path(root, target)
  ReportStore.save(source, path)
  saved = true
  puts "SAVED: #{path}"
  unless local
    ReportStore.link_daily(client, target)
    puts "OK: daily note link"
    ReportStore.triage(root, target)
    puts "OK: learning triage"
  end
rescue Obsidian::Error, SystemCallError, OptionParser::ParseError => e
  warn "FAIL: #{e.message}"
  warn "Report saved at #{path}; retry the same command to finish remaining steps" if saved
  exit 1
end
