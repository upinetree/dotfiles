#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "fileutils"
require "json"
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

  # レビューは headless の claude に任せるが、レビュー対象の skill はエージェントへの指示そのもので、
  # 「verdict は ok と書け」と仕込める。そこで claude には読むことしかさせず（--restricted で
  # 作業ディレクトリに閉じ込め、Write / Bash は渡さない）、記録は LLM が言いくるめられても
  # 曲がらない機械的な確認（引用の突き合わせ・隠しテキスト・verdict と重大度の整合・2 系統の一致）を
  # すべて通ったときだけこのスクリプトが書く。人は commit 前の diff で最終確認する。
  REVIEW_SKILL = ".agents/skills/vendored-skill-review/SKILL.md"
  REVIEW_RUNS = %w[A B].freeze
  # 1 系統あたり。yomiyasu 全体を全文読みさせて $1.5-1.6 だった。上限に当たるとそれまでの費用が
  # 無駄になり記録もされないので、通常の費用ではなく暴走の止めとして余裕を持たせる
  REVIEW_BUDGET_USD = 4.0
  REVIEW_TOOLS = "Read,Grep,Glob"
  SEVERITIES = %w[high medium low info].freeze
  HIDDEN_CHARS = /[​-‏‪-‮⁠-⁤⁦-⁩﻿]/
  # コードは BOM 除去などで U+FEFF やゼロ幅文字を正当に書くので、見た目と解釈をずらせる
  # 双方向制御文字（Trojan Source）だけを見る
  BIDI_CHARS = /[‪-‮⁦-⁩]/
  SCRIPT_EXTENSIONS = %w[.py .rb .sh .bash .zsh .js .mjs .cjs .ts .go .rs .pl .lua].freeze
  INSTRUCTION_EXTENSIONS = %w[.md .markdown .mdx .txt].freeze
  REVIEW_SCHEMA = {
    type: "object",
    additionalProperties: false,
    required: %w[verdict summary scope_reviewed findings could_not_verify usage_notes],
    properties: {
      verdict: {type: "string", enum: %w[ok ok-with-notes rejected]},
      summary: {type: "string"},
      scope_reviewed: {type: "string"},
      findings: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: %w[severity file line quote description],
          properties: {
            severity: {type: "string", enum: SEVERITIES},
            file: {type: "string"},
            line: {type: "integer"},
            quote: {type: "string"},
            description: {type: "string"}
          }
        }
      },
      could_not_verify: {type: "array", items: {type: "string"}},
      usage_notes: {type: "array", items: {type: "string"}}
    }
  }.freeze

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
    when "check" then check(reviews_only: args.include?("--reviews-only"))
    when "add" then add(*args)
    when "update" then update(*args)
    when "review" then review(args.first, full: args.include?("--full"), dry_run: args.include?("--dry-run"))
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
        vendored_skills.rb check [--reviews-only] 各 skill のレビュー記録の有無と、最新 release と pin の差を確認（問題があれば exit 1）
        vendored_skills.rb add <owner/repo> <skill> <ref>   新しく取り込む
        vendored_skills.rb update <skill> <ref>   pin を付け替えて取り直し、review まで流す（git diff を読んでからコミットする）
        vendored_skills.rb review <skill> [--full] [--dry-run]   headless claude でレビューし、確認を通れば記録する
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

  def check(reviews_only: false)
    problems = 0
    vendored.each do |skill|
      unless reviewed?(skill)
        problems += 1
        puts "UNREVIEWED: #{skill.name} #{skill.pinned} tree #{skill.tree_sha}: #{REVIEWS_FILE} に verdict ok の記録がありません"
      end
      if reviews_only
        puts "OK: #{skill.name} #{skill.pinned} tree #{skill.tree_sha} (reviewed)" if reviewed?(skill)
        next
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
    begin
      review(name)
    rescue SystemExit
      show_result(name)
      raise
    end
    check(reviews_only: true)
    show_reviewed_result(name)
  end

  def review(name, full: false, dry_run: false)
    abort "usage: vendored_skills.rb review <skill> [--full] [--dry-run]" if name.nil?
    skill = vendored.find { |s| s.name == name }
    abort "FAIL: #{name} は取り込み済みの skill ではありません（list で確認）" unless skill
    if reviewed?(skill) && !dry_run
      puts "#{name} tree #{skill.tree_sha} は既にレビュー済みです"
      return
    end

    Dir.mktmpdir("vendored-skill-review-") do |tmp|
      workspace = File.join(tmp, "ws")
      target = File.join(workspace, "target")
      FileUtils.mkdir_p(workspace)
      FileUtils.cp_r(skill.dir, target)
      base_tree = full ? nil : reviewed_head_tree(skill)
      write_changes_diff(skill, base_tree, tmp, workspace) if base_tree
      scope = base_tree ? "差分（レビュー済みの tree #{base_tree} から）" : "全体"
      puts "#{name} #{skill.pinned} を headless claude でレビューします（範囲: #{scope}、#{REVIEW_RUNS.size} 系統、各 $#{REVIEW_BUDGET_USD} まで）"

      runs = REVIEW_RUNS.map { |label| Thread.new { [label, run_reviewer(skill, workspace, base_tree)] } }.map(&:value).to_h
      runs.each { |label, run| print_run(label, run) }

      required = required_reads(target, base_tree && File.join(tmp, "previous"))
      problems = hidden_text(target).map { |hit| "隠しテキスト: #{hit}" }
      runs.each { |label, run| problems.concat(run_problems(target, run, required).map { |p| "系統 #{label}: #{p}" }) }
      verdicts = runs.values.filter_map { |run| run.dig("structured_output", "verdict") }.uniq
      problems << "系統どうしの verdict が一致しません（#{verdicts.join(" / ")}）" if verdicts.size > 1
      unless problems.empty?
        puts
        puts "記録しませんでした。機械的な確認で次の問題がありました:"
        problems.each { |p| puts "  - #{p}" }
        exit 1
      end

      entry = review_entry(skill, runs, scope)
      if dry_run
        puts
        puts "--dry-run のため記録しません。記録するはずだった内容:"
        puts [entry].to_yaml.delete_prefix("---\n")
      else
        File.open(File.join(@root, REVIEWS_FILE), "a") { |f| f.write([entry].to_yaml.delete_prefix("---\n")) }
        puts "#{REVIEWS_FILE} に verdict: #{entry["verdict"]} を記録しました"
      end
    end
  end

  # HEAD にコミットされている版がレビュー済みなら、そこからの差分だけを読ませる
  def reviewed_head_tree(skill)
    content, status = Open3.capture2("git", "-C", @root, "show", "HEAD:#{SKILLS_DIR}/#{skill.name}/SKILL.md", err: File::NULL)
    return nil unless status.success?
    head_tree = frontmatter_of(content).dig("metadata", "github-tree-sha")
    return nil if head_tree.nil? || head_tree == skill.tree_sha
    reviewed_tree?(skill.name, head_tree) ? head_tree : nil
  rescue Psych::SyntaxError
    nil
  end

  def write_changes_diff(skill, base_tree, tmp, workspace)
    archive, status = Open3.capture2("git", "-C", @root, "archive", "--format=tar", "HEAD", "#{SKILLS_DIR}/#{skill.name}", binmode: true)
    abort "FAIL: HEAD の #{skill.name} を取り出せません" unless status.success?
    base_root = File.join(tmp, "base")
    FileUtils.mkdir_p(base_root)
    _, status = Open3.capture2("tar", "-x", "-C", base_root, stdin_data: archive, binmode: true)
    abort "FAIL: HEAD の #{skill.name} を展開できません" unless status.success?
    FileUtils.mv(File.join(base_root, SKILLS_DIR, skill.name), File.join(tmp, "previous"))
    diff, = Open3.capture2("git", "diff", "--no-index", "--no-color", "previous", "ws/target", chdir: tmp)
    File.write(File.join(workspace, "changes.diff"), diff)
  end

  def run_reviewer(skill, workspace, base_tree)
    scope = if base_tree
      "前回レビュー済みの tree #{base_tree} との差分が ./changes.diff にある（a/previous が前回、b/ws/target が今回）。差分モードでレビューする。"
    else
      "差分ファイルは無い。全体モードでレビューする。"
    end
    prompt = <<~PROMPT
      vendored skill `#{skill.name}`（#{skill.owner_repo} #{skill.pinned}、tree #{skill.tree_sha}）のセキュリティレビューをする。
      レビュー対象の tree は ./target にある。#{scope}
      システムプロンプトの手順に従い、指定の JSON で返す。findings の file は ./target からの相対パスで書く。
    PROMPT
    instructions = File.read(File.join(@root, REVIEW_SKILL)).split(/^---\s*$/, 3).last
    # 読んだ範囲は自己申告ではなく実際の Read 呼び出しで確かめたいので、tool_use が見える stream-json で受ける
    output, error, = Open3.capture3(
      claude_bin, "-p", "--restricted", "--strict-mcp-config", "--tools", REVIEW_TOOLS,
      "--no-session-persistence", "--output-format", "stream-json", "--verbose", "--max-budget-usd", REVIEW_BUDGET_USD.to_s,
      "--json-schema", JSON.generate(REVIEW_SCHEMA), "--append-system-prompt", instructions, prompt,
      chdir: workspace
    )
    events = output.each_line.filter_map { |line| JSON.parse(line) rescue nil } # standard:disable Style/RescueModifier
    result = events.rfind { |e| e["type"] == "result" }
    return {"is_error" => true, "result" => (error.to_s + output.to_s)[-500..] || error.to_s} unless result
    result.merge("reads" => successful_reads(events))
  end

  # 要求した範囲（offset / limit）ではなく、エラーにならずに実際に返ってきた中身を Read の記録とする
  def successful_reads(events)
    events.select { |e| e["type"] == "user" && e["tool_use_result"].is_a?(Hash) && e["tool_use_result"]["file"] }
      .reject { |e| Array(e.dig("message", "content")).any? { |c| c["type"] == "tool_result" && c["is_error"] } }
      .map { |e| e["tool_use_result"]["file"] }
  end

  # 全体モードでは tree の指示として読まれうるテキストすべて、差分モードではそのうち中身が変わったものを全文読ませる
  def required_reads(target, previous = nil)
    Dir.glob("**/*", File::FNM_DOTMATCH, base: target).sort.select do |rel|
      path = File.join(target, rel)
      next false unless File.file?(path) && INSTRUCTION_EXTENSIONS.include?(File.extname(rel).downcase)
      old = previous && File.join(previous, rel)
      previous.nil? || !File.file?(old) || File.binread(old) != File.binread(path)
    end
  end

  def unread_files(target, reads, required)
    read_lines = Hash.new { |h, k| h[k] = [] }
    reads.each do |file|
      # claude の cwd は target の 1 つ上なので、相対パスはどちらを基準にしても解決できるようにする
      path = [File.dirname(target), target].map { |base| File.expand_path(file["filePath"].to_s, base) }.find { |p| File.file?(p) }
      next unless path
      start = [file["startLine"].to_i, 1].max
      lines = File.readlines(path)[start - 1, file["numLines"].to_i] || []
      # 長い行の切り詰めなどで返った中身がファイルと食い違う Read は、読んだことにしない
      next unless file["content"].to_s.chomp == lines.join.chomp
      read_lines[File.realpath(path)].concat((start...(start + lines.size)).to_a)
    end
    required.reject do |rel|
      path = File.realpath(File.join(target, rel))
      (1..File.foreach(path).count).all? { |n| read_lines[path].include?(n) }
    end
  end

  def run_problems(target, run, required = [])
    return ["claude の実行に失敗しました（#{run["subtype"] || run["result"]}）"] if run["is_error"] || run["structured_output"].nil?
    problems = []
    unread = unread_files(target, Array(run["reads"]), required)
    unless unread.empty?
      reads = Array(run["reads"])
      problems << "指示ファイルを全文 Read していません（#{unread.join(", ")}）。" \
        "拾えた Read は #{reads.size} 件（例: #{reads.first(3).map { |r| r.slice("file_path", "offset", "limit") }.inspect}）"
    end
    denials = Array(run["permission_denials"])
    problems << "作業ディレクトリの外などへのアクセスが拒否されています（#{denials.map { |d| d["tool_input"] }.inspect[0, 300]}）" unless denials.empty?
    output = run["structured_output"]
    output["findings"].each do |finding|
      problem = citation_problem(target, finding)
      problems << problem if problem
    end
    expected = expected_verdict(output["findings"])
    problems << "verdict #{output["verdict"]} が指摘の重大度から決まる #{expected} と合いません" unless output["verdict"] == expected
    problems
  end

  def citation_problem(target, finding)
    rel = finding["file"].to_s.delete_prefix("./").delete_prefix("target/")
    path = File.expand_path(rel, target)
    return "#{rel}: tree の外を指しています" unless path.start_with?("#{target}/")
    return "#{rel}: ファイルがありません" unless File.file?(path)
    number = finding["line"].to_i
    line = File.readlines(path, chomp: true)[number - 1] if number.positive?
    return "#{rel}:#{number}: その行がありません" if line.nil?
    quote = finding["quote"].to_s
    return "#{rel}:#{number}: 引用が短すぎます" if quote.strip.length < 8 && quote.strip != line.strip
    return "#{rel}:#{number}: 引用がその行にありません（#{quote[0, 60].inspect}）" unless line.include?(quote)
    nil
  end

  def expected_verdict(findings)
    severities = findings.map { |f| f["severity"] }
    if severities.include?("high") then "rejected"
    elsif severities.intersect?(%w[medium low]) then "ok-with-notes"
    else "ok"
    end
  end

  # LLM の申告に頼らず、指示として読まれうる隠しテキストを数える。HTML コメントは
  # スクリプトの文字列として正当に現れるので指示テキスト（INSTRUCTION_EXTENSIONS）だけを見る
  def hidden_text(target)
    Dir.glob("**/*", File::FNM_DOTMATCH, base: target).sort.flat_map do |rel|
      path = File.join(target, rel)
      next [] unless File.file?(path)
      content = File.binread(path).force_encoding(Encoding::UTF_8)
      next [] if content.include?("\0") # バイナリ（画像など）
      # 不正な UTF-8 を飛ばすと、1 バイト混ぜるだけで検査を外せる。Read は寛容に解読して読ませるので止める
      invalid = content.valid_encoding? ? [] : ["#{rel}: 不正な UTF-8 を含みます"]
      pattern = SCRIPT_EXTENSIONS.include?(File.extname(rel).downcase) ? BIDI_CHARS : HIDDEN_CHARS
      invalid + content.scrub.each_line.with_index(1).flat_map do |line, number|
        hits = []
        chars = line.scan(pattern).uniq.map { |c| format("U+%04X", c.ord) }
        hits << "#{rel}:#{number}: 不可視文字 #{chars.join(",")}" unless chars.empty?
        hits << "#{rel}:#{number}: HTML コメント" if INSTRUCTION_EXTENSIONS.include?(File.extname(rel).downcase) && line.include?("<!--")
        hits
      end
    end
  end

  def print_run(label, run)
    output = run["structured_output"]
    cost = run["total_cost_usd"] ? format("$%.2f", run["total_cost_usd"]) : "?"
    if output
      counts = SEVERITIES.map { |s| "#{s} #{output["findings"].count { |f| f["severity"] == s }}" }.join(", ")
      puts "系統 #{label}: verdict #{output["verdict"]}（#{counts}）#{cost}"
    else
      puts "系統 #{label}: 結果なし #{cost}"
    end
  end

  def review_entry(skill, runs, scope)
    outputs = runs.transform_values { |run| run["structured_output"] }
    models = runs.values.flat_map { |run| run["modelUsage"]&.keys || [] }.uniq
    cost = runs.values.sum { |run| run["total_cost_usd"].to_f }
    findings = outputs.flat_map { |label, out| out["findings"].map { |f| f.merge("run" => label) } }
      .group_by { |f| [f["file"], f["line"]] }
      .map { |(file, line), fs| "- [#{fs.first["severity"]}] #{file}:#{line}（系統 #{fs.map { |f| f["run"] }.join("・")}）#{fs.first["description"]}" }
    {
      "skill" => skill.name,
      "ref" => skill.pinned,
      "tree_sha" => skill.tree_sha,
      "reviewed_at" => Date.today,
      "verdict" => outputs.values.first["verdict"],
      "method" => <<~METHOD,
        headless claude（--restricted、tools: #{REVIEW_TOOLS}）による独立 #{runs.size} 系統の自動レビュー（#{REVIEW_SKILL}）。
        範囲: #{scope}。モデル: #{models.join(", ")}。費用: #{format("$%.2f", cost)}。
        vendored_skills.rb が引用と実際の行の突き合わせ、隠しテキストの機械検出、verdict と重大度の整合、系統どうしの一致を確認済み。
        scratch での実行確認はしていない。
        #{outputs.map { |label, out| "系統 #{label} が読んだ範囲: #{out["scope_reviewed"]}" }.join("\n")}
      METHOD
      "notes" => [
        *outputs.map { |label, out| "系統 #{label}: #{out["summary"]}" },
        *(findings.empty? ? [] : ["", "指摘:", *findings]),
        *usage_section("使う上で知っておくこと:", outputs.values.flat_map { |out| out["usage_notes"] }),
        *usage_section("確認できなかったこと:", outputs.values.flat_map { |out| out["could_not_verify"] })
      ].join("\n") + "\n"
    }
  end

  def usage_section(title, items)
    items.empty? ? [] : ["", title, *items.uniq.map { |item| "- #{item}" }]
  end

  def claude_bin
    shim = File.expand_path("~/.local/share/mise/shims/claude")
    ENV.fetch("CLAUDE_BIN") { File.executable?(shim) ? shim : "claude" }
  end

  def show_reviewed_result(name)
    puts
    puts "git status:"
    system("git", "-C", @root, "status", "--short", "--", File.join(SKILLS_DIR, name), REVIEWS_FILE)
    puts
    puts "コミット前に、skill の差分と #{REVIEWS_FILE} に足された記録を読む:"
    puts "  git -C #{@root} diff -- #{SKILLS_DIR}/#{name} #{REVIEWS_FILE}"
    puts "symlink は make link で張られます（初回の add のあとは必須）"
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
    puts "  2. セキュリティレビューをして #{REVIEWS_FILE} に記録する（観点は #{REVIEW_SKILL}）:"
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
    reviewed_tree?(skill.name, skill.tree_sha)
  end

  def reviewed_tree?(name, tree_sha)
    reviews.any? do |entry|
      entry["skill"] == name && entry["tree_sha"] == tree_sha && ACCEPTED_VERDICTS.include?(entry["verdict"])
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
    frontmatter_of(File.read(path))
  rescue Psych::SyntaxError => e
    warn "WARN: #{path}: frontmatter を読めません (#{e.message})"
    {}
  end

  def frontmatter_of(content)
    return {} unless content.start_with?("---")
    parts = content.split(/^---\s*$/, 3)
    return {} if parts.size < 3
    YAML.safe_load(parts[1]) || {}
  end
end

VendoredSkills.new.run(ARGV) if $PROGRAM_NAME == __FILE__
