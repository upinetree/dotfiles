#!/usr/bin/env ruby
# frozen_string_literal: true

# Upsert a report's learning counts into the learning triage queue
# (claude-report/_learning-triage.md in the Obsidian vault).
#
# Usage: append_to_triage.rb "<wikilink target>"
#   e.g. append_to_triage.rb "20260710_120000 セッションレポートのタイトル"
#
# Counts #learn/agent and #learn/knowledge tags in the report, then:
#   - no tags at all         -> do nothing
#   - no queue line yet      -> append '- [ ] [[target]] — agent N / knowledge M'
#   - unchecked line exists  -> update its counts in place
#   - checked line(s) only   -> append a fresh unchecked line (re-triage)
# Creates the queue file with an explanatory header on first use.

# Force UTF-8 regardless of locale (see link_to_daily.rb for rationale).
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

def obs(*args) = `obsidian #{args.join(' ')}`

target = ARGV[0]&.dup&.force_encoding(Encoding::UTF_8)
abort 'Usage: append_to_triage.rb "<wikilink target>"' unless target

vault = obs('vault').lines.grep(/\Apath\t/).first&.split("\t", 2)&.last&.strip
abort 'Could not resolve vault path from `obsidian vault`' unless vault

report = File.join(vault, 'claude-report', "#{target}.md")
abort "Report not found: #{report}" unless File.exist?(report)

body = File.read(report)
# Ignore tag mentions inside fenced code blocks and inline code spans — those
# are references to the convention, not tagged learning items.
prose = body.gsub(/^[ \t]*```.*?^[ \t]*```[ \t]*$/m, '').gsub(/`[^`\n]+`/, '')
agent = prose.scan(%r{#learn/agent\b}).size
knowledge = prose.scan(%r{#learn/knowledge\b}).size
if agent.zero? && knowledge.zero?
  puts 'No #learn tags found, skipping'
  exit
end

entry = "- [ ] [[#{target}]] — agent #{agent} / knowledge #{knowledge}"

queue = File.join(vault, 'claude-report', '_learning-triage.md')
unless File.exist?(queue)
  File.write(queue, <<~MD)
    # Claude 学びトリアージ

    report-session が学び付きレポートを保存するたびに自動追記するキュー。
    `/learning-review` が未チェック分の学びセクションを読んで [[_learning-map]] と
    CLAUDE.md / rules / skills への反映を検討し、処理後にチェックと処理結果を付ける。

  MD
end

lines = File.read(queue).lines(chomp: true)
idx = lines.index { _1.include?("[[#{target}]]") && _1.lstrip.start_with?('- [ ]') }

if idx
  lines[idx] = entry
  action = 'Updated'
else
  action = lines.any? { _1.include?("[[#{target}]]") } ? 'Re-queued' : 'Queued'
  lines << entry
end

File.write(queue, "#{lines.join("\n")}\n")
puts "#{action}: #{entry}"
