#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"

# skip-worktree 運用のファイル（.claude/settings.json のマシンローカル層）を
# リモートが変更すると素の git pull はブロックされる。flag 解除 → stash →
# pull → pop → flag 再設定を一括で行う。CLAUDE.md「PC-local settings」参照。
class Pull
  def initialize(root: File.expand_path("..", __dir__))
    @root = root
  end

  def run
    flagged = skip_worktree_files
    flagged.each do |file|
      git("update-index", "--no-skip-worktree", file) || abort("FAIL: --no-skip-worktree #{file}")
    end
    dirty = flagged.reject { |file| git("diff", "--quiet", "--", file) }
    if dirty.any? && !git("stash", "push", "--quiet", "-m", "make pull: machine-local", "--", *dirty)
      restore_flags(flagged)
      abort "FAIL: マシンローカル差分の stash に失敗しました"
    end
    unless git("pull")
      # merge 中断かネットワーク失敗かで後始末が違うため、自動で巻き戻さず手順だけ残す。
      warn "FAIL: git pull が失敗しました。解消後に手動で復旧してください:"
      warn "  git stash pop" if dirty.any?
      flagged.each { |file| warn "  git update-index --skip-worktree #{file}" }
      exit 1
    end
    if dirty.any? && !git("stash", "pop")
      warn "FAIL: stash pop がコンフリクトしました。解消後に flag を戻してください:"
      flagged.each { |file| warn "  git update-index --skip-worktree #{file}" }
      exit 1
    end
    restore_flags(flagged)
    puts "OK: pull 完了#{"（skip-worktree 復元: #{flagged.join(", ")}）" if flagged.any?}"
    puts "設定の検証は make doctor で行えます" if dirty.any?
  end

  private

  def git(*args)
    system("git", "-C", @root, *args)
  end

  def skip_worktree_files
    output, status = Open3.capture2("git", "-C", @root, "ls-files", "-v")
    abort "FAIL: git ls-files を実行できません" unless status.success?
    # assume-unchanged 併用時は小文字になるため両方拾う
    output.lines(chomp: true).filter_map { |line| line[2..] if line[0]&.casecmp?("s") }
  end

  def restore_flags(files)
    files.each { |file| git("update-index", "--skip-worktree", file) }
  end
end

Pull.new.run if $PROGRAM_NAME == __FILE__
