#!/usr/bin/env ruby
# frozen_string_literal: true

# Add a wikilink to a report under the '## Claude Reports' section of today's daily note.
#
# Usage: link_to_daily.rb "<wikilink target>"
#   e.g. link_to_daily.rb "20260616_071100 セッションレポートのタイトル"
#
# Resolves the current daily note via the obsidian CLI, inserts '- [[<target>]]'
# at the end of the '## Claude Reports' section (creating the section at the end
# of the note if it does not exist), and writes the file back in place.
# Idempotent: skips if the target is already linked.

# Force UTF-8 everywhere regardless of locale. When invoked without LANG/LC_ALL
# set (as in non-interactive harnesses), Ruby defaults the external/filesystem
# encodings to US-ASCII, so File.read returns US-ASCII content. Comparing that
# against a multibyte argument raises Encoding::CompatibilityError.
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

SECTION = '## Claude Reports'

# Run the obsidian CLI and return stdout. The CLI prints non-fatal
# 'Loading…'/'installer out of date' warnings to stdout, so callers filter
# for the meaningful line themselves.
def obs(*args) = `obsidian #{args.join(' ')}`

# ARGV strings are tagged with the startup locale's encoding, which the
# assignment above cannot retroactively change — retag the raw bytes as UTF-8.
target = ARGV[0]&.dup&.force_encoding(Encoding::UTF_8)
abort 'Usage: link_to_daily.rb "<wikilink target>"' unless target

# Vault root: the line beginning with "path\t".
vault = obs('vault').lines.grep(/\Apath\t/).first&.split("\t", 2)&.last&.strip
abort 'Could not resolve vault path from `obsidian vault`' unless vault

# Daily note relative path: the last non-empty stdout line (skips warnings).
rel = obs('daily:path').lines.map(&:strip).reject(&:empty?).last
abort 'Could not resolve daily note path' unless rel

note = File.join(vault, rel)
abort "Daily note not found: #{note}" unless File.exist?(note)

lines = File.read(note).lines(chomp: true)
link = "- [[#{target}]]"

# Idempotent: bail out if this report is already linked anywhere.
if lines.any? { _1.include?(target) }
  puts "Already linked in #{rel}, skipping"
  exit
end

idx = lines.index { _1.strip == SECTION }
if idx.nil?
  # Append a fresh section at the end of the note.
  lines << '' unless lines.empty? || lines.last.strip.empty?
  lines.push(SECTION, '', link)
else
  # Section spans from idx+1 to the next '## ' heading (or EOF). Insert the
  # link after the last non-empty line inside it.
  rest = lines[(idx + 1)..]
  span = rest.index { _1.start_with?('## ') } || rest.length
  offset = (0...span).reject { rest[_1].strip == '' }.last
  insert_at = offset.nil? ? idx + 1 : idx + 1 + offset + 1
  lines.insert(insert_at, link)
end

File.write(note, "#{lines.join("\n")}\n")
puts "Linked to #{rel}"
