# frozen_string_literal: true

module FormatSkip
  FLAG_NAMES = ["skip-format", "skip-format.local"].freeze

  def self.skip?(file_path, ext)
    return true if File.exist?("/tmp/.claude-skip-format")
    return true if File.exist?("/tmp/.claude-skip-format#{ext}")

    repo_roots_for(file_path).any? do |root|
      FLAG_NAMES.any? do |name|
        File.exist?(File.join(root, ".claude", name)) || File.exist?(File.join(root, ".claude", "#{name}#{ext}"))
      end
    end
  end

  # worktree では --show-toplevel が worktree 自身を指し、gitignore 済みの .local フラグは
  # 新しい worktree に無い。本体の checkout（git-common-dir の親）に置いたフラグも効かせる
  def self.repo_roots_for(file_path)
    dir = File.directory?(file_path) ? file_path : File.dirname(file_path)
    out = IO.popen(
      ["git", "-C", dir, "rev-parse", "--path-format=absolute", "--show-toplevel", "--git-common-dir"],
      err: File::NULL, &:read
    )
    return [] unless $?.success?

    toplevel, common_dir = out.lines.map(&:chomp)
    [toplevel, File.dirname(common_dir)].uniq
  rescue
    []
  end
end
