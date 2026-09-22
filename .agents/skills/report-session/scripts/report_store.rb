# frozen_string_literal: true

require "fileutils"
require "tempfile"
require_relative "obsidian"

module ReportStore
  module_function

  def validate_target(target)
    unless target && target.match?(/\A\d{8}_\d{6} .+\z/) && !target.match?(/[\x00-\x1f#^\[\]|\\\/:*?"<>]/) && !target.end_with?(".", " ")
      raise Obsidian::Error, "Expected a safe filename stem: TIMESTAMP TITLE"
    end
  end

  # Replace a whole note only after the new bytes are ready, so a failed write
  # cannot leave the daily note or triage queue truncated.
  def replace(path, content)
    Tempfile.create([".report-session-", ".md"], File.dirname(path)) do |file|
      file.binmode
      file.write(content)
      file.flush
      file.chmod(File.stat(path).mode & 0o777) if File.exist?(path)
      File.rename(file.path, path)
    end
  end

  def report_path(vault, target)
    validate_target(target)
    directory = File.join(vault, "claude-report")
    FileUtils.mkdir_p(directory)
    unless File.realpath(directory).start_with?(File.realpath(vault) + "/")
      raise Obsidian::Error, "Report directory is outside the selected root"
    end
    File.join(directory, "#{target}.md")
  end

  def save(source, path)
    body = File.binread(source)
    if File.exist?(path)
      raise Obsidian::Error, "Report already exists with different content: #{path}" unless File.binread(path) == body
    else
      # Publish only complete bytes. A hard link, unlike rename, also refuses
      # to overwrite a report created by another process after the check.
      Tempfile.create([".report-session-", ".md"], File.dirname(path)) do |file|
        file.binmode
        file.write(body)
        file.flush
        file.fsync
        file.chmod(0o644 & ~File.umask)
        file.close
        File.link(file.path, path)
      end
    end
    path
  end

  def link_daily(client, target)
    validate_target(target)
    note = client.daily_path
    lines = File.read(note, encoding: "UTF-8").lines(chomp: true)
    link = "- [[#{target}]]"
    return if lines.any? { _1.include?("[[#{target}]]") }

    idx = lines.index { _1.strip == "## Claude Reports" }
    if idx.nil?
      lines << "" unless lines.empty? || lines.last.empty?
      lines.push("## Claude Reports", "", link)
    else
      rest = lines[(idx + 1)..]
      span = rest.index { _1.start_with?("## ") } || rest.length
      offset = (0...span).reject { rest[_1].strip.empty? }.last
      lines.insert(offset.nil? ? idx + 1 : idx + 2 + offset, link)
    end
    replace(note, "#{lines.join("\n")}\n")
  end

  def triage(vault, target)
    report = report_path(vault, target)
    body = File.read(report, encoding: "UTF-8")
    prose = body.gsub(/^[ \t]*```.*?^[ \t]*```[ \t]*$/m, "").gsub(/`[^`\n]+`/, "")
    agent = prose.scan(%r{#learn/agent\b}).size
    knowledge = prose.scan(%r{#learn/knowledge\b}).size
    return if agent.zero? && knowledge.zero?

    entry = "- [ ] [[#{target}]] — agent #{agent} / knowledge #{knowledge}"
    queue = File.join(vault, "claude-report", "_learning-triage.md")
    body = if File.exist?(queue)
      File.read(queue, encoding: "UTF-8")
    else
      "# Claude 学びトリアージ\n\nreport-session の学びを learning-review で消化するキュー。\n\n"
    end
    lines = body.lines(chomp: true)
    idx = lines.index { _1.include?("[[#{target}]]") && _1.lstrip.start_with?("- [ ]") }
    idx ? lines[idx] = entry : lines << entry
    replace(queue, "#{lines.join("\n")}\n")
  end
end
