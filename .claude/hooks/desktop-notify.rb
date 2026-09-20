#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"
require "cgi"

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
      # XML と PowerShell の両方で、通知文をコードとして解釈させない。
      xml = '<toast><visual><binding template="ToastGeneric">' \
        "<text>#{CGI.escapeHTML(title)}</text><text>#{CGI.escapeHTML(message)}</text>" \
        "</binding></visual></toast>"
      # BurntToast なら通知処理は短くなるが、追加モジュールの導入・更新管理が必要になる。
      # 現状の通知要件では依存を維持管理しなくてよい方を優先し、標準 API を直接使う。
      script = <<~POWERSHELL
        $ErrorActionPreference = 'Stop'
        $ProgressPreference = 'SilentlyContinue'
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        try {
          [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
          [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
          [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
          $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
          $xml.LoadXml([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('#{Base64.strict_encode64(xml)}')))
          # 既存の Windows PowerShell の AppUserModelID を使い、登録処理を不要にする。
          $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe'
          $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)
          # Windows PowerShell では Setting が null になる環境があるため、取得できた場合だけ判定する。
          $setting = $notifier.Setting
          if ($null -ne $setting -and $setting.ToString() -ne 'Enabled') { throw "Windows notifications disabled: $setting" }
          $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
          $notifier.Show($toast)
          exit 0
        } catch {
          [Console]::Error.WriteLine($_.Exception.Message)
          [Console]::Error.WriteLine($_.InvocationInfo.PositionMessage)
          exit 1
        }
      POWERSHELL
      ["powershell.exe", "-NoProfile", "-NonInteractive", "-EncodedCommand", Base64.strict_encode64(script.encode("UTF-16LE"))]
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
