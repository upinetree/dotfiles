#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "open3"

# Homebrew の cask が使えない macOS アプリ（公証されず disabled になったものなど）は、
# mise の [bootstrap.packages] macos-app で GitHub release の DMG を版と sha256 固定で入れる。
# macos-app は新しい release を検知できない（docs: "macos-app cannot discover releases"）ので、
# その検知と版・sha256 の書き換えだけをここで受け持ち、取得・照合・配置は mise に任せる。
# mise の設定は Ruby 標準ライブラリで読めない TOML なので、
# `[bootstrap.packages."macos-app:<name>"]` のテーブル形式で文字列値だけを書く前提で読み書きする。
class VendoredApps
  CONFIG_FILE = ".config/mise/.config.toml"
  TABLE_HEADER = /\A\[bootstrap\.packages\."macos-app:(?<name>[^"]+)"\]\s*\z/
  KEY_VALUE = /\A(?<key>\w+)\s*=\s*"(?<value>[^"]*)"\s*\z/
  RELEASE_URL = %r{\Ahttps://github\.com/(?<repo>[^/]+/[^/]+)/releases/download/(?<tag>[^/]+)/(?<asset>[^/]+)\z}
  VERSION_PLACEHOLDER = "{{version}}"

  App = Struct.new(:name, :values, :lines) do
    def version = values["version"]

    def sha256 = values["sha256"]

    def release = values["url"]&.match(RELEASE_URL)

    def repo = release && release[:repo]

    def tag_for(version) = release[:tag].gsub(VERSION_PLACEHOLDER, version)

    def asset_for(version) = release[:asset].gsub(VERSION_PLACEHOLDER, version)

    def version_from_tag(tag)
      pattern = Regexp.escape(release[:tag]).sub(Regexp.escape(VERSION_PLACEHOLDER), "(.+)")
      tag[/\A#{pattern}\z/, 1]
    end
  end

  def initialize(root: File.expand_path("..", __dir__))
    @root = root
  end

  def run(argv)
    command, *args = argv
    case command
    when nil, "list" then list
    when "check" then check
    when "update" then update(*args)
    else
      usage
      exit 1
    end
  end

  private

  def usage
    warn <<~USAGE
      usage:
        vendored_apps.rb [list]               #{CONFIG_FILE} の macos-app と入っている版を表示
        vendored_apps.rb check                最新 release と固定した版の差を確認（差があれば exit 1）
        vendored_apps.rb update <name> [<tag>]  版と sha256 を release の値に書き換えて入れる（tag 省略時は最新）
    USAGE
  end

  def list
    if apps.empty?
      puts "#{CONFIG_FILE} に macos-app のエントリはありません"
      return
    end
    installed = installed_versions
    apps.each do |app|
      puts "#{app.name}\t#{app.repo || "(not a GitHub release URL)"}\t#{app.version}\tinstalled: #{installed[app.name].to_s.empty? ? "-" : installed[app.name]}"
    end
  end

  def check
    problems = 0
    apps.each do |app|
      unless app.repo
        puts "WARN: #{app.name}: url が GitHub release ではないので確認できません"
        next
      end
      release = release_info(app.repo)
      latest = release && app.version_from_tag(release["tagName"])
      if latest.nil?
        puts "WARN: #{app.name}: 最新 release を取得できません (#{app.repo})"
      elsif latest == app.version
        puts "OK: #{app.name} #{app.version} (latest)"
      else
        problems += 1
        puts "UPDATE: #{app.name} #{app.version} -> #{latest}  (make apps-update NAME=#{app.name})"
      end
    end
    exit 1 if problems.positive?
  end

  def update(name = nil, tag = nil)
    if name.nil?
      usage
      exit 1
    end
    app = apps.find { |a| a.name == name }
    abort "FAIL: #{CONFIG_FILE} に macos-app:#{name} がありません" unless app
    abort "FAIL: #{name}: url が GitHub release ではないので更新できません" unless app.repo

    release = release_info(app.repo, tag)
    abort "FAIL: #{app.repo} の release #{tag || "(latest)"} を取得できません" unless release
    version = app.version_from_tag(release["tagName"])
    abort "FAIL: tag #{release["tagName"]} が url の tag の形 #{app.release[:tag]} に合いません" unless version
    asset = release["assets"].find { |a| a["name"] == app.asset_for(version) }
    abort "FAIL: release #{release["tagName"]} に #{app.asset_for(version)} がありません" unless asset
    sha256 = asset["digest"].to_s.delete_prefix("sha256:")
    abort "FAIL: #{asset["name"]} の sha256 digest を GitHub から取得できません" unless sha256.match?(/\A\h{64}\z/)

    if version == app.version && sha256 == app.sha256
      puts "#{name} は既に #{version} です"
    else
      rewrite(app, "version" => version, "sha256" => sha256)
      puts "#{CONFIG_FILE}: #{name} #{app.version} -> #{version}"
    end

    ok = system("mise", "bootstrap", "packages", "apply", "--yes", "macos-app:#{name}")
    abort "FAIL: mise bootstrap packages apply に失敗しました" unless ok
    puts
    puts "コミット前に差分を読む: git -C #{@root} diff -- #{CONFIG_FILE}"
  end

  # テーブル内の該当行がちょうど 1 つずつあることを確かめてから、1 回だけ書き込む
  def rewrite(app, changes)
    lines = File.readlines(config_path)
    changes.each do |key, value|
      targets = app.lines.select { |i| lines[i].match(KEY_VALUE)&.[](:key) == key }
      abort "FAIL: macos-app:#{app.name} の #{key} 行が #{targets.size} 個あります（1 個のはず）" unless targets.size == 1
      lines[targets.first] = %(#{key} = "#{value}"\n)
    end
    File.write(config_path, lines.join)
  end

  def apps
    @apps ||= begin
      result = []
      current = nil
      File.readlines(config_path, chomp: true).each_with_index do |line, i|
        if (header = line.match(TABLE_HEADER))
          current = App.new(name: header[:name], values: {}, lines: [])
          result << current
        elsif line.start_with?("[")
          current = nil
        elsif current
          current.lines << i
          if (pair = line.match(KEY_VALUE))
            current.values[pair[:key]] = pair[:value]
          end
        end
      end
      result
    end
  end

  def release_info(repo, tag = nil)
    args = ["gh", "release", "view", *tag, "--repo", repo, "--json", "tagName,assets"]
    output, status = Open3.capture2(*args, err: File::NULL)
    status.success? ? JSON.parse(output) : nil
  end

  def installed_versions
    output, status = Open3.capture2("mise", "bootstrap", "packages", "status", "--json", err: File::NULL)
    return {} unless status.success?
    packages = JSON.parse(output).dig("macos-app", "packages") || []
    packages.to_h { |p| [p["package"], p["installed_version"]] }
  end

  def config_path
    File.join(@root, CONFIG_FILE)
  end
end

VendoredApps.new.run(ARGV) if $PROGRAM_NAME == __FILE__
