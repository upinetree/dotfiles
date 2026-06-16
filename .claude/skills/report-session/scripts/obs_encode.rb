#!/usr/bin/env ruby
# frozen_string_literal: true

# Encode a markdown file for the obsidian create content= parameter.
#
# Obsidian CLI represents newlines as literal \n and requires " to be escaped.
# Usage: obs_encode.rb <file_path>

abort 'Usage: obs_encode.rb <file_path>' unless ARGV.size == 1

ESCAPES = { '\\' => '\\\\', '"' => '\\"', "\n" => '\\n', "\t" => '\\t' }.freeze

print File.read(ARGV[0]).gsub(/[\\"\n\t]/) { ESCAPES[_1] }
