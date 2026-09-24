#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "shellwords"

# skip-worktree 運用のファイル（.claude/settings.json のマシンローカル層）を
# リモートが変更すると素の git pull はブロックされる。flag 解除 → stash →
# pull → pop → flag 再設定を一括で行う。CLAUDE.md「PC-local settings」参照。
class Pull
  def initialize(root: File.expand_path("..", __dir__))
    @root = root
  end

  def run
    flagged = skip_worktree_files
    lift_flags(flagged)
    dirty = flagged.reject { |file| clean?(file) }
    if dirty.any? && !git("stash", "push", "--quiet", "-m", "make pull: machine-local", "--", *dirty)
      warn "FAIL: マシンローカル差分の stash に失敗しました"
      restore_flags_or_instruct(flagged)
      exit 1
    end
    unless git("pull")
      # merge 中断かネットワーク失敗かで正しい後始末が違うため、自動で巻き戻さず手順だけ残す。
      warn "FAIL: git pull が失敗しました。解消後に手動で復旧してください:"
      warn "  git stash pop" if dirty.any?
      instruct_flag_restore(flagged)
      exit 1
    end
    if dirty.any? && !git("stash", "pop")
      warn "FAIL: stash pop がコンフリクトしました。解消後に flag を戻してください:"
      instruct_flag_restore(flagged)
      exit 1
    end
    unless restore_flags(flagged)
      warn "FAIL: skip-worktree を復元できませんでした。手動で戻してください:"
      instruct_flag_restore(flagged)
      exit 1
    end
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

  def lift_flags(files)
    lifted = []
    files.each do |file|
      unless git("update-index", "--no-skip-worktree", file)
        warn "FAIL: --no-skip-worktree #{file}"
        restore_flags_or_instruct(lifted)
        exit 1
      end
      lifted << file
    end
  end

  # skip-worktree 中は git add が効かないので staged 差分は通常無いが、
  # CLAUDE.md のコミット手順（flag 解除→add→commit→再設定）を途中で
  # 中断すると staged のみ残り pull がブロックされるため index 側も見る。
  # stash pop は --index を付けないため staged 状態自体は戻らない（内容は保持）
  def clean?(file)
    git("diff", "--quiet", "--", file) && git("diff", "--cached", "--quiet", "--", file)
  end

  def restore_flags(files)
    files.map { |file| git("update-index", "--skip-worktree", file) }.all?
  end

  def restore_flags_or_instruct(files)
    return if restore_flags(files)
    warn "skip-worktree を復元できませんでした。手動で戻してください:"
    instruct_flag_restore(files)
  end

  def instruct_flag_restore(files)
    files.each { |file| warn "  git update-index --skip-worktree #{Shellwords.escape(file)}" }
  end
end

Pull.new.run if $PROGRAM_NAME == __FILE__
