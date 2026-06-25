#!/usr/bin/env ruby
# frozen_string_literal: true

# Claude Code hook: Notification / Stop イベントの内容を VOICEVOX で読み上げる。
#
# - Stop        : transcript から最後のアシスタント返答を取り出し、冒頭 1〜2 文を読む
# - Notification: ずんだもん時は内容を一般化した定型セリフをランダムに(詳細は画面で
#                 分かる前提)、それ以外の話者は渡された message をそのまま読む
#
# エンジン(http://127.0.0.1:50021)が停止していたら、バックグラウンドで自動起動を
# 仕掛けてその回はスキップする(次回の hook から読み上げる)。
# hook を絶対に失敗させないため、例外はすべて握りつぶして exit 0 で抜ける。
#
# 環境変数:
#   VOICEVOX_HOST       既定 127.0.0.1:50021
#   VOICEVOX_SPEAKER    既定 3 (ずんだもん ノーマル)
#   VOICEVOX_MAXLEN     既定 120 (読み上げ最大文字数)
#   VOICEVOX_ENGINE_BIN 既定 /Applications/VOICEVOX.app/.../vv-engine/run
#                       (未起動時に自動起動するエンジン本体。空にすると自動起動しない)
#   VOICEVOX_ZUNDAMON_STYLES 既定 1,3,5,7,22,38,75,76
#                       (この SPEAKER のとき語尾を「のだ」口調に簡易変換する)
#
# エンジンの手動操作:
#   停止 : lsof -ti:50021 | xargs kill
#   状態 : curl -s http://127.0.0.1:50021/version
#   (停止後、次の hook で自動的に再起動される。完全に止めるなら本スクリプトの
#    hook 登録を settings.json から外すか VOICEVOX_ENGINE_BIN を空にする)

require "json"
require "net/http"
require "uri"
require "tempfile"

HOST = ENV.fetch("VOICEVOX_HOST", "127.0.0.1:50021")
SPEAKER = ENV.fetch("VOICEVOX_SPEAKER", "3")
MAXLEN = Integer(ENV.fetch("VOICEVOX_MAXLEN", "120"))
BASE = "http://#{HOST}".freeze

# エンジン未起動なら GUI なしでバックグラウンド起動する(初回はその回をスキップ)
ENGINE_BIN = ENV.fetch(
  "VOICEVOX_ENGINE_BIN",
  "/Applications/VOICEVOX.app/Contents/Resources/vv-engine/run"
)
LAUNCH_LOCK = "/tmp/voicevox-engine.launching"
LAUNCH_COOLDOWN = 60 # 秒。直近に起動を試みていたら再起動しない(立ち上がり待ち)

# 読み上げにくいパターンを省略するときに代わりに読む語
OMIT_WORDS = %w[ぺけぺけ うんたら なんちゃら ほにゃらら].freeze

# ずんだもんのスタイル ID(エンジンの /speakers 由来)。選択時に「のだ」口調にする
zunda_default = "1,3,5,7,22,38,75,76"
ZUNDAMON_STYLES = ENV.fetch("VOICEVOX_ZUNDAMON_STYLES", zunda_default)
  .split(",").map(&:strip).reject(&:empty?).to_set

def http(method, path, data: nil, headers: {}, timeout: 10)
  uri = URI("#{BASE}#{path}")
  klass = (method == "POST") ? Net::HTTP::Post : Net::HTTP::Get
  req = klass.new(uri)
  headers.each { |k, v| req[k] = v }
  req.body = data if data
  Net::HTTP.start(uri.host, uri.port, open_timeout: timeout, read_timeout: timeout) do |conn|
    conn.request(req).body
  end
end

def engine_alive?
  http("GET", "/version", timeout: 1)
  true
rescue
  false
end

# エンジンが落ちていれば GUI なしでバックグラウンド起動する。
#
# 複数 hook(Notification/Stop)が同時に走っても二重起動しないよう、起動を
# 試みた時刻(LAUNCH_LOCK の mtime)によるクールダウンと flock で抑制する。
# 起動コマンドを投げるだけで再生はしない(呼び出し側がこの後 return する)。
def try_launch_engine
  return if ENGINE_BIN.empty? || !File.exist?(ENGINE_BIN)

  # 直近に起動を試みていれば、立ち上がり待ちとみなしスキップ
  begin
    return if Time.zone.now - File.mtime(LAUNCH_LOCK) < LAUNCH_COOLDOWN
  rescue SystemCallError
    # ロックファイルがまだ無い場合は続行
  end

  lock = File.open(LAUNCH_LOCK, "w") # open("w") で mtime 更新 = クールダウン起点
  return unless lock.flock(File::LOCK_EX | File::LOCK_NB) # 別の hook が起動処理中

  host, port = HOST.split(":")
  logf = File.open("/tmp/voicevox-engine.log", "ab")
  pid = Process.spawn(
    ENGINE_BIN, "--host", host || "127.0.0.1", "--port", port || "50021",
    out: logf, err: logf, in: File::NULL,
    pgroup: true # 親(hook プロセス)終了後も生存させる
  )
  Process.detach(pid)
rescue
  nil
end

# transcript(JSONL) から、テキストを含む最後の assistant 発言を返す。
def last_assistant_text(transcript_path)
  text = ""
  File.foreach(transcript_path, encoding: "utf-8") do |line|
    line = line.strip
    next if line.empty?

    begin
      obj = JSON.parse(line)
    rescue
      next
    end
    next unless obj["type"] == "assistant"

    content = (obj["message"] || {})["content"]
    case content
    when String
      text = content unless content.strip.empty?
    when Array
      joined = content
        .select { |b| b.is_a?(Hash) && b["type"] == "text" }
        .map { |b| b["text"].to_s }
        .join.strip
      text = joined unless joined.empty?
    end
  end
  text
rescue
  text
end

# マークダウン/コード/URL/記号を落として読み上げ用の素のテキストにする。
def clean(text)
  text = text.gsub(/```.*?```/m, "")                  # コードブロック
  text = text.gsub(/`([^`]*)`/, '\1')                 # インラインコード(内容は残す)
  text = text.gsub(%r{https?://\S+}, "")              # URL
  text = text.gsub(/!?\[([^\]]*)\]\([^)]*\)/, '\1')  # リンク/画像
  text = text.gsub(/^\s*[#>\-*|]+\s*/, "")            # 行頭記号

  # 読み上げにくい技術的パターンを省略語に置換（アンダースコア除去より先に行う）
  omit = proc { OMIT_WORDS.sample }
  text = text.gsub(%r{(?:~?/|\.{1,2}/)[\w.-]+(?:/[\w.-]+)+}, &omit)  # ファイルパス
  # 英字・数字の両方を含む16進数列のみ(純英単語・純数字の誤検知を抑制)
  text = text.gsub(/\b(?=[a-f0-9]*[a-f])(?=[a-f0-9]*[0-9])[a-f0-9]{7,40}\b/, &omit) # コミットハッシュ
  text = text.gsub(/\b[A-Z][A-Z0-9]*_[A-Z0-9_]+\b/) { |m| m.downcase.tr("_", " ") } # 環境変数・定数名
  text = text.gsub(/\b[a-z][a-z0-9]*_[a-z0-9_]+\b/) { |m| m.tr("_", " ") } # スネークケース識別子
  text = text.gsub(/\bv?\d+(?:\.\d+){2,}\b/, &omit)                      # バージョン番号(3桁以上)

  text = text.gsub(/[*_~#>`|]/, "")                   # 残りの装飾記号
  text = text.tr("\n", " ")
  text.gsub(/\s+/, " ").strip
end

# 先頭 max_sentences 文、ただし MAXLEN 文字でも打ち切る。
def head_sentences(text, max_sentences: 2)
  sentences = text.split(/(?<=[。！？!?])/, -1)
  out = +""
  sentences.each do |s|
    next if s.empty?
    break if !out.empty? && out.length + s.length > MAXLEN

    out << s
    count = out.count("。！？!?")
    break if count >= max_sentences
  end
  out = text if out.empty?
  out = out[0, MAXLEN] if out.length > MAXLEN
  out.strip
end

# 文末表現 → ずんだもん口調。長い/具体的なものから順に判定する(最初の一致を採用)
ZUNDA_RULES = [
  %w[でしょうか なのだ],
  %w[ていますか ているのだ],
  %w[しますか するのだ],
  %w[ませんか ないのだ],
  %w[ましたか したのだ],
  %w[ですか なのだ],
  %w[ますか のだ],
  %w[でしょう なのだ],
  %w[ていました ていたのだ],
  %w[しました したのだ],
  # 五段動詞の音便: 「ました」直前の仮名で過去形を作る(促音便・撥音便)
  %w[りました ったのだ], # 直り→直った
  %w[ちました ったのだ], # 待ち→待った
  %w[いました ったのだ], # 買い→買った
  %w[みました んだのだ], # 読み→読んだ
  %w[びました んだのだ], # 飛び→飛んだ
  %w[にました んだのだ], # 死に→死んだ
  %w[ました たのだ],
  %w[ません ないのだ],
  %w[ましょう するのだ],
  %w[ています ているのだ],
  %w[します するのだ],
  %w[です なのだ],
  %w[ます のだ],
  %w[である なのだ],
  %w[だった だったのだ],
  %w[した したのだ],
  %w[ない ないのだ],
  %w[だ なのだ]
].freeze

# 文末の丁寧/断定表現を「のだ」口調に簡易変換する(ルールベース・近似)。
#
# 形態素解析はしないので、よくある文末パターンだけを文ごとに置換する。
# 変換できない文末(体言止め等)はそのまま残す。
def zundamon_style(text)
  parts = text.split(/([。！？!?])/, -1) # 区切り文字も保持して分割
  parts.each_with_index.map do |seg, i|
    next seg if i.odd? # 区切り文字はそのまま

    body = seg.rstrip
    tail = seg[body.length..] # 末尾空白を保持
    unless body.end_with?("のだ") # 既に「のだ」口調なら二重変換しない
      ZUNDA_RULES.each do |key, val|
        if body.end_with?(key)
          body = body[0...-key.length] + val
          break
        end
      end
    end
    body + tail
  end.join
end

# Notification を一般化したずんだもんの定型セリフ(詳細は画面で分かる前提)
NOTIFY_ZUNDA = {
  "permission" => [
    "許可がほしいのだ！",
    "ボクに権限をくれるのだ？",
    "確認してほしいのだ！",
    "ゴーサインを待ってるのだ！",
    "ポチッとしてほしいのだ！"
  ],
  "idle" => [
    "次の指示がほしいのだ！",
    "ボク、待ってるのだ！",
    "ボク、手が空いちゃったのだ。",
    "なにをすればいいのだ？"
  ],
  "default" => [
    "お知らせなのだ！",
    "ちょっと見てほしいのだ！",
    "呼んでるのだ！"
  ]
}.freeze

# Notification の読み上げ文を決める。
#
# ずんだもん(ZUNDAMON_STYLES)のときは内容を一般化した定型セリフをランダムに返す。
# 許可待ち/入力待ちだけ message から大まかに判定して出し分ける。
# それ以外の話者では message をそのまま整形して返す。
def notification_text(message)
  return clean(message.to_s) unless ZUNDAMON_STYLES.include?(SPEAKER)

  msg = message.to_s.downcase
  key =
    if %w[permission approve allow].any? { |k| msg.include?(k) }
      "permission"
    elsif %w[waiting input idle].any? { |k| msg.include?(k) }
      "idle"
    else
      "default"
    end
  NOTIFY_ZUNDA[key].sample
end

def speak(text)
  return if text.empty?

  q = URI.encode_www_form("text" => text, "speaker" => SPEAKER)
  query = http("POST", "/audio_query?#{q}", timeout: 10)
  wav = http("POST", "/synthesis?speaker=#{SPEAKER}", data: query,
    headers: {"Content-Type" => "application/json"}, timeout: 30)
  tf = Tempfile.new(["voicevox", ".wav"])
  tf.binmode
  tf.write(wav)
  tf.close
  begin
    system("afplay", tf.path)
  ensure
    begin
      File.unlink(tf.path)
    rescue SystemCallError
      nil
    end
  end
end

def main
  begin
    data = JSON.parse($stdin.read)
  rescue
    return
  end

  case data["hook_event_name"]
  when "Notification"
    text = notification_text(data["message"].to_s)
  when "Stop"
    raw = last_assistant_text(data["transcript_path"].to_s)
    text = head_sentences(clean(raw))
  else
    return
  end

  text = zundamon_style(text) if ZUNDAMON_STYLES.include?(SPEAKER)
  return if text.empty?

  unless engine_alive?
    # 今回は起動を仕掛けるだけでスキップ。次回の hook から読み上げる
    try_launch_engine
    return
  end

  begin
    speak(text)
  rescue
    nil
  end
end

main if __FILE__ == $PROGRAM_NAME
