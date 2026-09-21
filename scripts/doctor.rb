#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"
require "shellwords"

class Doctor
  def initialize(root: File.expand_path("..", __dir__), home: ENV.fetch("HOME"))
    @root = root
    @home = home
    @failures = 0
    @runtimes = {}
  end

  def run
    check_links
    check_hooks
    puts "診断完了: #{@failures} 件の問題"
    @failures.zero?
  end

  private

  def report(ok, message)
    @failures += 1 unless ok
    puts "#{ok ? "OK" : "FAIL"}: #{message}"
  end

  def check_links
    output, error, status = Open3.capture3("bash", "scripts/link.sh", "--list", chdir: @root)
    unless status.success? && !output.empty?
      report(false, "symlink 定義を取得できません: #{error.strip}")
      return
    end
    pairs = output.split("\0").map do |pair|
      source, destination = pair.split(":", 2)
      [File.join(@root, source), destination.sub(/\A~/) { @home }]
    end
    pairs << [File.join(@root, "CLAUDE.md"), File.join(@root, "AGENTS.md")]
    pairs.each do |source, destination|
      if !File.symlink?(destination)
        report(false, "#{destination}: #{File.exist?(destination) ? "実ファイル/ディレクトリになっています" : "未作成です"} (make link を確認)")
      elsif !File.exist?(destination)
        report(false, "#{destination}: リンク切れです (参照先: #{File.readlink(destination)})")
      elsif File.realpath(destination) != File.realpath(source)
        report(false, "#{destination}: 参照先が違います (期待: #{source})")
      else
        report(true, "symlink #{destination}")
      end
    rescue SystemCallError => e
      report(false, "#{destination}: #{e.message}")
    end
  rescue SystemCallError => e
    report(false, "symlink 診断: #{e.message}")
  end

  def check_hooks
    [".claude/settings.json", ".codex/hooks.json"].each do |relative|
      path = File.join(@home, relative)
      hooks = JSON.parse(File.read(path)).fetch("hooks")
      count = 0
      hooks.each do |event, groups|
        groups.each do |group|
          group.fetch("hooks").each do |hook|
            next unless hook["type"] == "command"
            count += 1
            check_command(hook.fetch("command"), "#{relative} #{event}")
          end
        end
      end
      report(false, "#{path}: command hook がありません") if count.zero?
    rescue SystemCallError, JSON::ParserError, KeyError, TypeError, NoMethodError => e
      report(false, "#{path}: 設定を読めません (#{e.message})")
    end
  end

  def check_command(command, label)
    # 設定をシェルで評価すると通知や編集が発火するため、対応する直接呼び出しだけを検査する。
    runtime, script, *arguments = Shellwords.split(command)
    runtime = expand_home(runtime.to_s)
    script = expand_home(script.to_s)
    unless %w[ruby bash sh].include?(File.basename(runtime)) && script.start_with?("/") &&
        [runtime, script, *arguments].none? { |word| word.match?(/[\$`|;&<>\n]/) }
      report(false, "#{label}: 自動診断に未対応の command 形式です。Ruby / Bash / sh の直接呼び出しを指定してください")
      return
    end
    unless @runtimes.key?(runtime)
      probe = (File.basename(runtime) == "ruby") ? ["--version"] : ["-c", "exit 0"]
      output, error, status = Open3.capture3(runtime, *probe)
      @runtimes[runtime] = status.success?
      report(status.success?, "runtime #{runtime}#{status.success? ? "" : ": #{error.strip} #{output.strip}"}")
    end
    report(File.file?(script) && File.readable?(script), "#{label}: script #{script}")
  rescue SystemCallError, ArgumentError => e
    report(false, "#{label}: #{e.message}")
  end

  def expand_home(value)
    value.sub(/\A(?:\$HOME|\$\{HOME\}|~)(?=\/)/) { @home }
  end
end

exit(Doctor.new.run ? 0 : 1) if $PROGRAM_NAME == __FILE__
