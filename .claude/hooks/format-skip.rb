# frozen_string_literal: true

module FormatSkip
  def self.skip?(file_path, ext)
    return true if File.exist?("/tmp/.claude-skip-format")
    return true if File.exist?("/tmp/.claude-skip-format#{ext}")

    repo_root = repo_root_for(file_path)
    return false unless repo_root

    return true if File.exist?(File.join(repo_root, ".claude", "skip-format"))
    return true if File.exist?(File.join(repo_root, ".claude", "skip-format.local"))
    return true if File.exist?(File.join(repo_root, ".claude", "skip-format#{ext}"))
    return true if File.exist?(File.join(repo_root, ".claude", "skip-format.local#{ext}"))

    false
  end

  def self.repo_root_for(file_path)
    dir = File.directory?(file_path) ? file_path : File.dirname(file_path)
    out = IO.popen(["git", "-C", dir, "rev-parse", "--show-toplevel"], err: File::NULL, &:read)
    $?.success? ? out.chomp : nil
  rescue
    nil
  end
end
