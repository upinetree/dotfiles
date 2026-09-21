#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "json"

# デスクトップ通知が使えない環境でも、エージェントの hook を失敗させない。
doctor = ARGV.delete("--doctor")
message, title, sound = doctor ? ["通知が表示されたら動作確認成功です", "dotfiles doctor", "Glass"] : ARGV
exit 0 unless message && title

begin
  command = case RUBY_PLATFORM
  when /darwin/
    script = <<~APPLESCRIPT
      on run argv
        display notification (item 1 of argv) with title (item 2 of argv) sound name (item 3 of argv)
      end run
    APPLESCRIPT
    ["osascript", "-e", script, message, title, sound || "Glass"]
  when /linux/
    if File.read("/proc/sys/kernel/osrelease").match?(/microsoft/i)
      # Windows バイナリを /bin/sh が読み始める前に、WSL の実行登録を確認する。
      binfmt = "/proc/sys/fs/binfmt_misc"
      interop = File.readable?("#{binfmt}/status") && File.read("#{binfmt}/status").strip == "enabled" &&
        Dir.glob("#{binfmt}/WSLInterop*").any? { |path| File.read(path).lines.first&.strip == "enabled" }
      unless interop
        abort "FAIL: WSL の Windows 実行機能 (binfmt WSLInterop) が未登録・無効、または参照できません。Windows 側で作業を保存して wsl --shutdown を実行し、WSL を開き直してください。" if doctor
        exit 0
      end
      # 通知文はデータとして渡し、PowerShell のコードとして解釈させない。
      payload = Base64.strict_encode64(JSON.generate([title, message]))
      # WinRT の互換性対応を自前で維持する代わりに BurntToast を使う。
      # 追加依存の診断負担は doctor の導入確認・インストール案内で抑える。
      script = <<~POWERSHELL
        $ErrorActionPreference = 'Stop'
        $ProgressPreference = 'SilentlyContinue'
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        try {
          if (-not (Get-Module -ListAvailable -Name BurntToast)) {
            throw 'BurntToast is not installed. Run in Windows PowerShell: Install-Module -Name BurntToast -Scope CurrentUser -Repository PSGallery'
          }
          Import-Module BurntToast -ErrorAction Stop
          #{doctor ? "Write-Output ('OK: BurntToast ' + (Get-Module BurntToast).Version)" : ""}
          $text = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('#{payload}')) | ConvertFrom-Json
          New-BurntToastNotification -Text $text -ErrorAction Stop | Out-Null
          exit 0
        } catch {
          [Console]::Error.WriteLine($_.Exception.Message)
          [Console]::Error.WriteLine($_.InvocationInfo.PositionMessage)
          exit 1
        }
      POWERSHELL
      # 既定の Restricted でもモジュールを読めるよう、このプロセスだけに適用する。
      ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "RemoteSigned", "-EncodedCommand", Base64.strict_encode64(script.encode("UTF-16LE"))]
    else
      ["notify-send", "--", title, message]
    end
  end
  if doctor
    abort "FAIL: 通知未対応の OS です (#{RUBY_PLATFORM})" unless command
    executable = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, command.first) }
      .find { |path| File.file?(path) && File.executable?(path) }
    unless executable
      hint = (command.first == "powershell.exe") ? "WSL の Windows PATH 引き継ぎと相互運用設定を確認してください。" : "通知コマンドをインストールしてください。"
      abort "FAIL: #{command.first} が見つかりません。#{hint}"
    end
    puts "OK: #{executable}"
    puts "テスト通知を送信します。"
    $stdout.flush
    success = system(*command)
    abort "FAIL: 通知コマンドが失敗しました。上のエラーとデスクトップの通知サービスを確認してください。" unless success
    puts "OK: 通知コマンドは正常終了しました。画面への表示は目視で確認してください。"
  elsif command
    system(*command, out: File::NULL, err: File::NULL)
  end
rescue SystemCallError => e
  abort "FAIL: #{e.message}" if doctor
  # コマンド未導入やデスクトップセッション不在は通知のスキップとして扱う。
end

exit 0
