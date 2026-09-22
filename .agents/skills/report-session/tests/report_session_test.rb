# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "rbconfig"
require_relative "../scripts/report_store"

class ReportSessionTest < Minitest::Test
  SCRIPTS = File.expand_path("../scripts", __dir__)
  TARGET = "20260922_120000 日本語のレポート"

  def setup
    @env = ENV.to_h
    @tmp = Dir.mktmpdir("report-session-")
    @vault = File.join(@tmp, "日本語 vault")
    FileUtils.mkdir_p(File.join(@vault, "daily"))
    @note = File.join(@vault, "daily", "today.md")
    File.write(@note, "# 今日\n\n## Other\nkeep me\n")
    @source = File.join(@tmp, "source.md")
    File.write(@source, "# 日本語のレポート\n\n- 知見 #learn/agent\n- 知識 #learn/knowledge\n```ruby\nputs '\\n' #learn/agent\n```\n")
    @cli = File.join(@tmp, "fake CLI")
    File.write(@cli, <<~RUBY)
      #!#{RbConfig.ruby}
      require "json"
      File.open(ENV.fetch("FAKE_LOG"), "a") { _1.puts JSON.generate(ARGV) }
      abort "simulated CLI failure" if ENV["FAKE_FAIL"] == "1"
      case ARGV.last
      when "vault"
        if ENV["FAKE_BAD"] == "1"
          puts "Error: CLI disabled"
        else
          print "Loading…\\r\\nname\\tTest Vault\\r\\npath\\t" + ENV.fetch("FAKE_VAULT").dup.force_encoding("UTF-8") + "\\r\\n"
        end
      when "daily:path"
        puts ENV.fetch("FAKE_DAILY", "daily/today.md")
      when "tags"
        puts "ruby"
      else
        abort "unexpected command"
      end
    RUBY
    File.chmod(0o755, @cli)
    ENV["OBSIDIAN_CLI"] = @cli
    ENV.delete("OBSIDIAN_VAULT")
    ENV["FAKE_VAULT"] = @vault
    ENV["FAKE_LOG"] = File.join(@tmp, "commands.jsonl")
  end

  def teardown
    ENV.replace(@env)
    FileUtils.remove_entry(@tmp)
  end

  def invoke(script, *args)
    Open3.capture3(RbConfig.ruby, File.join(SCRIPTS, script), *args)
  end

  def save(*options)
    invoke("save_report.rb", *options, @source, TARGET)
  end

  def report
    File.join(@vault, "claude-report", "#{TARGET}.md")
  end

  def queue
    File.join(@vault, "claude-report", "_learning-triage.md")
  end

  def test_native_cli_and_vault_pinning
    client = Obsidian.new(wsl: false)
    assert_equal File.realpath(@vault), client.vault
    assert_equal "ruby\n", client.tags
    assert_equal @note, client.daily_path
    args = File.readlines(ENV.fetch("FAKE_LOG")).map { JSON.parse(_1) }
    assert_equal ["vault=Test Vault", "tags"], args[1]
    assert_equal ["vault=Test Vault", "daily:path"], args[2]
  end

  def test_windows_paths_and_crlf
    converter = File.join(@tmp, "wslpath")
    File.write(converter, "#!#{RbConfig.ruby}\nabort 'wrong args' unless ARGV == ['-u', 'C:\\\\Users\\\\User\\\\日本語 vault']\nputs #{@vault.dump}\n")
    File.chmod(0o755, converter)
    ENV["PATH"] = @tmp + File::PATH_SEPARATOR + ENV.fetch("PATH")
    ENV["FAKE_VAULT"] = 'C:\\Users\\User\\日本語 vault'
    ENV["FAKE_DAILY"] = 'daily\\today.md'
    client = Obsidian.new(wsl: true)
    assert_equal @vault, client.vault
    assert_equal @note, client.daily_path
  end

  def test_missing_and_broken_cli_are_distinct
    ENV.delete("OBSIDIAN_CLI")
    ENV["PATH"] = @tmp
    assert_raises(Obsidian::Missing) { Obsidian.new(wsl: false) }
    ENV["OBSIDIAN_CLI"] = File.join(@tmp, "missing")
    _, err, status = invoke("obsidian.rb", "check")
    assert_equal 1, status.exitstatus
    assert_includes err, "FAIL:"
  end

  def test_path_discovery
    ENV.delete("OBSIDIAN_CLI")
    ENV["PATH"] = @tmp
    File.symlink(@cli, File.join(@tmp, "obsidian"))
    assert_equal @vault, Obsidian.new(wsl: false).vault
  end

  def test_explicit_vault_id_is_preserved
    ENV["OBSIDIAN_VAULT"] = "vault-id"
    client = Obsidian.new(wsl: false)
    client.vault
    client.tags
    commands = File.readlines(ENV.fetch("FAKE_LOG")).map { JSON.parse(_1) }
    assert_equal [["vault=vault-id", "vault"], ["vault=vault-id", "tags"]], commands
  end

  def test_connection_failure_does_not_save_elsewhere
    ENV["FAKE_FAIL"] = "1"
    _, err, status = save
    assert_equal 1, status.exitstatus
    assert_includes err, "simulated CLI failure"
    refute File.exist?(report)
  end

  def test_success_exit_with_invalid_vault_is_failure
    ENV["FAKE_BAD"] = "1"
    _, err, status = invoke("obsidian.rb", "check")
    assert_equal 1, status.exitstatus
    assert_includes err, "Could not resolve vault"
  end

  def test_nonexistent_vault_is_failure
    ENV["FAKE_VAULT"] = File.join(@tmp, "missing vault")
    _, _, status = invoke("obsidian.rb", "check")
    assert_equal 1, status.exitstatus
  end

  def test_save_preserves_bytes_and_retry_does_not_duplicate
    2.times do
      out, err, status = save
      assert status.success?, "#{out}\n#{err}"
    end
    assert_equal File.binread(@source), File.binread(report)
    assert_equal 1, File.read(@note).scan("[[#{TARGET}]]").size
    assert_includes File.read(@note), "keep me"
    assert_equal 1, File.read(queue).scan("[[#{TARGET}]]").size
    assert_includes File.read(queue), "agent 1 / knowledge 1"
  end

  def test_missing_daily_note_can_be_retried
    File.unlink(@note)
    _, err, status = save
    assert_equal 1, status.exitstatus
    assert_includes err, "Report saved at"
    assert File.file?(report)
    refute File.exist?(queue)
    File.write(@note, "# 今日\n")
    _, err, status = save
    assert status.success?, err
    assert_equal 1, File.read(@note).scan("[[#{TARGET}]]").size
    assert File.file?(queue)
  end

  def test_triage_failure_can_be_retried
    FileUtils.mkdir_p(queue)
    _, err, status = save
    assert_equal 1, status.exitstatus
    assert_includes err, "Report saved at"
    assert_includes File.read(@note), "[[#{TARGET}]]"
    Dir.rmdir(queue)
    _, err, status = save
    assert status.success?, err
    assert_equal 1, File.read(@note).scan("[[#{TARGET}]]").size
    assert_equal 1, File.read(queue).scan("[[#{TARGET}]]").size
  end

  def test_different_existing_content_is_preserved
    _, _, status = save
    assert status.success?
    original = File.binread(report)
    File.write(@source, "changed")
    _, err, status = save
    assert_equal 1, status.exitstatus
    assert_includes err, "different content"
    assert_equal original, File.binread(report)
  end

  def test_initial_write_failure_leaves_no_report_and_can_be_retried
    File.binwrite(@source, "x" * 2048)
    root = File.join(@tmp, "local")
    target = File.join(root, "claude-report", "#{TARGET}.md")
    script = <<~RUBY
      Signal.trap("XFSZ", "IGNORE")
      Process.setrlimit(Process::RLIMIT_FSIZE, 512)
      load ARGV.shift
    RUBY
    _, err, status = Open3.capture3(RbConfig.ruby, "-e", script,
      File.join(SCRIPTS, "save_report.rb"), "--local", root, @source, TARGET)
    assert_equal 1, status.exitstatus
    assert_includes err, "File too large"
    refute File.exist?(target)
    assert_empty Dir.glob(File.join(root, "claude-report", ".report-session-*"))

    _, err, status = save("--local", root)
    assert status.success?, err
    assert_equal File.binread(@source), File.binread(target)
  end

  def test_concurrent_report_is_not_overwritten
    target = File.join(@tmp, "concurrent.md")
    original_link = File.method(:link)
    published_bytes = nil
    publish = lambda do |temporary, destination|
      published_bytes = File.binread(temporary)
      File.write(destination, "another report")
      original_link.call(temporary, destination)
    end
    begin
      File.define_singleton_method(:link, &publish)
      assert_raises(Errno::EEXIST) { ReportStore.save(@source, target) }
    ensure
      File.define_singleton_method(:link, original_link)
    end
    assert_equal File.binread(@source), published_bytes
    assert_equal "another report", File.read(target)
    assert_empty Dir.glob(File.join(@tmp, ".report-session-*"))
  end

  def test_local_save_never_calls_cli
    ENV["FAKE_FAIL"] = "1"
    root = File.join(@tmp, "local")
    _, err, status = save("--local", root)
    assert status.success?, err
    assert_equal File.binread(@source), File.binread(File.join(root, "claude-report", "#{TARGET}.md"))
    refute File.exist?(ENV.fetch("FAKE_LOG"))
  end

  def test_updated_learning_requeues_checked_entry
    save
    File.write(queue, File.read(queue).sub("- [ ]", "- [x]"))
    File.open(report, "a") { _1.puts "- another #learn/agent" }
    2.times do
      _, err, status = invoke("append_to_triage.rb", TARGET)
      assert status.success?, err
    end
    assert_equal 1, File.read(queue).scan("- [ ]").size
    assert_equal 1, File.read(queue).scan("- [x]").size
    assert_includes File.read(queue), "agent 2 / knowledge 1"
  end

  def test_daily_outside_vault_is_rejected
    ENV["FAKE_DAILY"] = @source
    _, err, status = save
    assert_equal 1, status.exitstatus
    assert_includes err, "outside the selected vault"
    refute_includes File.read(@source), "[[#{TARGET}]]"
  end

  def test_non_utf8_locale_preserves_japanese_arguments
    ENV["LC_ALL"] = "C"
    _, err, status = save
    assert status.success?, err
    assert_equal File.binread(@source), File.binread(report)
    assert_includes File.read(@note), "[[#{TARGET}]]"
  end

  def test_existing_section_and_in_vault_symlink_are_preserved
    real_note = File.join(@vault, "real.md")
    File.rename(@note, real_note)
    File.write(real_note, "# 今日\n## Claude Reports\n- [[older]]\n\n## Other\nkeep me\n")
    File.symlink(real_note, @note)
    _, err, status = save
    assert status.success?, err
    assert File.symlink?(@note)
    assert_includes File.read(real_note), "- [[older]]\n- [[#{TARGET}]]\n\n## Other"
  end
end
