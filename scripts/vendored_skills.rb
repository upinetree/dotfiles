#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "open3"
require "tmpdir"
require "yaml"

# 他人の skill は `gh skill install --pin <tag> --dir .agents/skills` で tag 固定の
# コピーとして repo に取り込み、更新のたびにセキュリティレビューをして
# REVIEWS_FILE に記録してからコミットする（CLAUDE.md「Vendored third-party skills」参照）。
# gh skill は取得元・pin・tree SHA を SKILL.md の frontmatter（metadata.github-*）に
# 書き込むので、別の lock ファイルは持たず frontmatter を台帳として読む。
# レビュー記録は tree SHA で突き合わせる（tag は動かせるが tree SHA は内容そのもの）。
class VendoredSkills
  SKILLS_DIR = ".agents/skills"
  REVIEWS_FILE = ".agents/vendored-skills-reviews.yml"
  ACCEPTED_VERDICTS = %w[ok ok-with-notes].freeze

  Skill = Struct.new(:name, :dir, :repo, :pinned, :tree_sha, :path) do
    # "https://github.com/owner/repo" -> "owner/repo"
    def owner_repo
      repo.sub(%r{\A(https?://)?github\.com/}, "").sub(/\.git\z/, "")
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
    when "add" then add(*args)
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
        vendored_skills.rb [list]                 取り込み済み skill と pin を表示
        vendored_skills.rb check                  各 skill のレビュー記録の有無と、最新 release と pin の差を確認（問題があれば exit 1）
        vendored_skills.rb add <owner/repo> <skill> <ref>   新しく取り込む
        vendored_skills.rb update <skill> <ref>   pin を付け替えて取り直す（git diff を読んでからコミットする）
    USAGE
  end

  def list
    skills = vendored
    if skills.empty?
      puts "取り込み済みの skill はありません"
      return
    end
    skills.each do |skill|
      puts "#{skill.name}\t#{skill.owner_repo}\t#{skill.pinned || "(unpinned)"}\t#{skill.tree_sha}\t#{review_label(skill)}"
    end
  end

  def check
    problems = 0
    vendored.each do |skill|
      unless reviewed?(skill)
        problems += 1
        puts "UNREVIEWED: #{skill.name} #{skill.pinned} tree #{skill.tree_sha}: #{REVIEWS_FILE} に verdict ok の記録がありません"
      end
      latest = latest_release(skill.owner_repo)
      if latest.nil?
        puts "WARN: #{skill.name}: 最新 release を取得できません (#{skill.owner_repo})"
      elsif latest == skill.pinned
        puts "OK: #{skill.name} #{skill.pinned} (latest)"
      else
        problems += 1
        puts "UPDATE: #{skill.name} #{skill.pinned || "(unpinned)"} -> #{latest}  (make skills-update NAME=#{skill.name} REF=#{latest})"
      end
    end
    exit 1 if problems.positive?
  end

  def add(owner_repo = nil, name = nil, ref = nil)
    if [owner_repo, name, ref].any?(&:nil?)
      usage
      exit 1
    end
    if File.exist?(skill_dir(name))
      abort "FAIL: #{SKILLS_DIR}/#{name} は既にあります。更新なら update を使ってください"
    end
    install(owner_repo, name, ref)
    show_result(name)
  end

  def update(name = nil, ref = nil)
    if [name, ref].any?(&:nil?)
      usage
      exit 1
    end
    skill = vendored.find { |s| s.name == name }
    abort "FAIL: #{name} は取り込み済みの skill ではありません（list で確認）" unless skill
    # gh skill install --force は上書きだけでローカルに残った余分なファイルを消さない。
    # upstream の tag と同じ状態を git diff に出すため、旧コピーを退避してから入れ直す。
    Dir.mktmpdir("vendored-skill-") do |tmp|
      backup = File.join(tmp, name)
      FileUtils.mv(skill.dir, backup)
      begin
        install(skill.owner_repo, name, ref)
      rescue SystemExit, Interrupt
        FileUtils.rm_rf(skill.dir)
        FileUtils.mv(backup, skill.dir)
        warn "取り込みに失敗したので #{skill.pinned} のコピーを戻しました"
        raise
      end
    end
    show_result(name)
  end

  def install(owner_repo, name, ref)
    ok = system("gh", "skill", "install", owner_repo, name, "--pin", ref, "--dir", File.join(@root, SKILLS_DIR), "--force")
    abort "FAIL: gh skill install に失敗しました" unless ok
  end

  def show_result(name)
    skill = vendored.find { |s| s.name == name }
    puts
    puts "git status（#{SKILLS_DIR}/#{name}）:"
    system("git", "-C", @root, "status", "--short", "--", File.join(SKILLS_DIR, name))
    puts
    puts "コミット前に:"
    puts "  1. 差分を読む: git -C #{@root} diff -- #{SKILLS_DIR}/#{name}"
    puts "  2. セキュリティレビューをして #{REVIEWS_FILE} に記録する（観点は CLAUDE.md「Vendored third-party skills」）:"
    puts "       - skill: #{name}"
    puts "         ref: #{skill&.pinned}"
    puts "         tree_sha: #{skill&.tree_sha}"
    puts "         reviewed_at: #{Time.now.strftime("%Y-%m-%d")}"
    puts "         verdict: ok | ok-with-notes | rejected"
    puts "         method: ..."
    puts "         notes: |"
    puts "  3. make skills-check が UNREVIEWED を出さないことを確かめてから commit する"
    puts "symlink は make link で張られます（初回の add のあとは必須）"
  end

  def review_label(skill)
    reviewed?(skill) ? "reviewed" : "UNREVIEWED"
  end

  def reviewed?(skill)
    reviews.any? do |entry|
      entry["skill"] == skill.name && entry["tree_sha"] == skill.tree_sha && ACCEPTED_VERDICTS.include?(entry["verdict"])
    end
  end

  def reviews
    @reviews ||= begin
      path = File.join(@root, REVIEWS_FILE)
      File.exist?(path) ? Array(YAML.safe_load_file(path, permitted_classes: [Date])) : []
    rescue Psych::SyntaxError => e
      warn "WARN: #{REVIEWS_FILE} を読めません (#{e.message})"
      []
    end
  end

  def latest_release(owner_repo)
    output, status = Open3.capture2("gh", "release", "view", "--repo", owner_repo, "--json", "tagName", "--jq", ".tagName", err: File::NULL)
    status.success? ? output.strip : nil
  end

  def skill_dir(name)
    File.join(@root, SKILLS_DIR, name)
  end

  def vendored
    Dir.glob(File.join(@root, SKILLS_DIR, "*", "SKILL.md")).sort.filter_map do |path|
      metadata = frontmatter(path)["metadata"]
      next unless metadata.is_a?(Hash) && metadata["github-repo"]
      Skill.new(
        name: File.basename(File.dirname(path)),
        dir: File.dirname(path),
        repo: metadata["github-repo"],
        pinned: metadata["github-pinned"],
        tree_sha: metadata["github-tree-sha"],
        path: metadata["github-path"]
      )
    end
  end

  def frontmatter(path)
    content = File.read(path)
    return {} unless content.start_with?("---")
    parts = content.split(/^---\s*$/, 3)
    return {} if parts.size < 3
    YAML.safe_load(parts[1]) || {}
  rescue Psych::SyntaxError => e
    warn "WARN: #{path}: frontmatter を読めません (#{e.message})"
    {}
  end
end

VendoredSkills.new.run(ARGV) if $PROGRAM_NAME == __FILE__
