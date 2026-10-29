#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"

# Shared by report-session and learning-review; stdout is data, stderr is diagnostics.
class Obsidian
  class Error < StandardError; end
  class Missing < Error; end

  def initialize(wsl: File.readable?("/proc/sys/kernel/osrelease") && File.read("/proc/sys/kernel/osrelease").match?(/microsoft/i))
    @wsl = wsl
    @command = ENV["OBSIDIAN_CLI"] || executable("obsidian")
    if !@command && @wsl
      @command = executable("Obsidian.com") || Dir.glob([
        "/mnt/c/Users/*/AppData/Local/Obsidian/Obsidian.com",
        "/mnt/c/Users/*/AppData/Local/Programs/Obsidian/Obsidian.com",
        "/mnt/c/Program Files/Obsidian/Obsidian.com"
      ]).select { File.executable?(it) }.then do |paths|
        raise Error, "Multiple Windows CLIs found; set OBSIDIAN_CLI to one executable path" if paths.size > 1
        paths.first
      end
    end
    raise Missing, "Obsidian CLI not found" unless @command
    @name = ENV["OBSIDIAN_VAULT"]
  end

  def executable(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { File.join(it, name) }.find { File.file?(it) && File.executable?(it) }
  end

  def run(*args)
    out, err, status = Open3.capture3(*args, binmode: true)
    out = out.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF").gsub("\r\n", "\n")
    raise Error, "Command failed (#{status.exitstatus}): #{err.force_encoding(Encoding::UTF_8).strip}\n#{out.strip}" unless status.success?
    raise Error, "CLI output is not UTF-8" unless out.valid_encoding?
    out
  rescue SystemCallError => e
    raise Error, e.message
  end

  def query(command)
    run(@command, *(@name ? ["vault=#{@name}"] : []), command)
  end

  # CLI は起動直後などに同一コマンドでも間欠的に失敗・不完全応答を返すことがあり、
  # 直後の再実行では成功する（2026-10-29 のレポート保存で観測）。読み取り系の
  # CLI 呼び出しとその出力パースだけを包むこと（ファイルシステムの検証など、
  # 再実行しても結果が変わらない安定条件には使わない）。
  RETRY_ATTEMPTS = 3

  def retrying
    attempt = 0
    begin
      yield
    rescue Error => e
      attempt += 1
      raise if attempt >= RETRY_ATTEMPTS
      warn "retrying (#{attempt}/#{RETRY_ATTEMPTS - 1}) after: #{e.message.lines.first&.strip}"
      sleep attempt
      retry
    end
  end

  def local_path(path)
    if @wsl && path.match?(/\A(?:[A-Za-z]:[\\\/]|\\\\)/)
      run("wslpath", "-u", path).strip
    else
      path
    end
  end

  def vault
    return @vault if @vault
    info = retrying do
      parsed = query("vault").lines.filter_map do |line|
        key, value = line.strip.split("\t", 2)
        [key, value] if value
      end.to_h
      raise Error, "Could not resolve vault name/path" unless parsed["name"] && parsed["path"]
      parsed
    end
    path = local_path(info.fetch("path"))
    raise Error, "Vault is not an accessible absolute directory: #{path}" unless path.start_with?("/") && File.directory?(path) && File.readable?(path) && File.executable?(path)
    @name ||= info.fetch("name")
    @vault = File.realpath(path)
  end

  def daily_path
    root = vault
    rel = retrying do
      line = query("daily:path").lines.map(&:strip).reject(&:empty?).last
      raise Error, "Could not resolve daily note path" unless line&.end_with?(".md")
      line
    end
    path = File.expand_path(local_path(rel).tr("\\", "/"), root)
    raise Error, "Daily note not found: #{path}" unless File.file?(path)
    path = File.realpath(path)
    raise Error, "Daily note is outside the selected vault" unless path.start_with?(root + "/")
    path
  end

  def tags
    vault
    retrying { query("tags") }
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    client = Obsidian.new
    case ARGV.fetch(0, "check")
    when "check"
      puts JSON.generate(vault: client.vault)
    when "vault"
      puts client.vault
    when "tags"
      print client.tags
    else
      raise Obsidian::Error, "Usage: obsidian.rb [check|vault|tags]"
    end
  rescue Obsidian::Missing => e
    warn "UNAVAILABLE: #{e.message} (local report storage is available)"
    warn "WSL setup: references/setup-wsl.md" if File.readable?("/proc/sys/kernel/osrelease") && File.read("/proc/sys/kernel/osrelease").match?(/microsoft/i)
    exit 2
  rescue Obsidian::Error => e
    warn "FAIL: #{e.message}"
    exit 1
  end
end
