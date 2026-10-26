# HTML の artifact を、版の差分が読めるテキストにする。
#
# HTML のまま diff を取ると、1 行が長いせいで 1 文の変更が段落ごとの差分になり、
# どの節の変更かも読めない。ブロックごとに改行し、さらに「。」で 1 文 1 行に割り、
# 行頭にいちばん内側の id（[#i-2-9] など）を付けて、差分の行だけで場所が分かるようにする。
#
#   ruby artifact_text.rb text <page.html> <out.txt>
#   ruby artifact_text.rb diff <old.txt> <new.txt> <out.diff> --from v141 --to v142 [--note "..."]
#
# diff は変更のあった行の id を sections= に出す。変更が無ければ out.diff を書かずに終了コード 3 を返す。
# Ruby の標準ライブラリには HTML パーサーが無いので、artifact の HTML（タグの対応は publish 前に確かめてある）
# を読める程度の小さなトークナイザーで済ませている。

require "fileutils"
require "json"
require "open3"
require "optparse"
require "strscan"

# 割り方を変えると、前の版で作った text/current.txt と全行が食い違う。changelog に写して見分ける。
# 3 は Python 版（artifact_text.py）と同じ出力で、Ruby への移植では上げていない。
# 4 でセルの中の <br>・<p> などで新しいセルに分かれていたのを直した（それ以降のセル番号がずれていた）
TOOL_VERSION = 4

SKIP = %w[style svg head noscript].freeze
BLOCK = %w[
  p li h1 h2 h3 h4 h5 h6 div section article header footer main summary details blockquote dt dd
  table thead tbody ul ol pre figure figcaption nav aside
].freeze
VOID = %w[br img hr meta link input wbr col source].freeze
RAW_TEXT = %w[script style].freeze
OPEN = "（(「『【［"
CLOSE = "）)」』】］"
ENTITIES = {"amp" => "&", "lt" => "<", "gt" => ">", "quot" => '"', "apos" => "'", "nbsp" => " "}.freeze

def unescape(text)
  text.gsub(/&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z][a-zA-Z0-9]*);/) do
    ref = Regexp.last_match(1)
    if ref.start_with?("#x") then [ref[2..].to_i(16)].pack("U")
    elsif ref.start_with?("#") then [ref[1..].to_i].pack("U")
    else ENTITIES.fetch(ref, "&#{ref};")
    end
  end
end

# 「。」で割るが、括弧の中では割らない（「（試行中。読み方は …）」を 1 行に保つ）
def sentences(text)
  out = []
  cur = +""
  depth = 0
  text.each_char do |ch|
    cur << ch
    if OPEN.include?(ch)
      depth += 1
    elsif CLOSE.include?(ch)
      depth = [depth - 1, 0].max
    elsif ch == "。" && depth.zero?
      out << cur.strip
      cur = +""
    end
  end
  out << cur.strip
  out.reject(&:empty?)
end

class Extractor
  attr_reader :lines

  def initialize
    @lines = []
    @stack = [] # [tag, id or nil]
    @skip = 0
    @buf = []
    @cells = nil # tr の中では td/th をセルごとに集める
    @in_cell = false
    @pre = 0
    @script = nil # インラインの script の中身。表やガントのデータを JS で持つページがある
  end

  def feed(html)
    s = StringScanner.new(html)
    until s.eos?
      if s.scan(/<!--.*?-->/m) || s.scan(/<![^>]*>/)
        next
      elsif s.scan(%r{<(/?)([a-zA-Z][a-zA-Z0-9-]*)((?:[^>"']|"[^"]*"|'[^']*')*)>})
        closing, tag, attrs = s[1] == "/", s[2].downcase, s[3]
        if closing
          end_tag(tag)
        else
          start_tag(tag, attrs)
          if RAW_TEXT.include?(tag)
            body = s.scan_until(%r{(?=</#{tag}\s*>)}i) || s.rest.tap { s.terminate }
            data(body)
          elsif attrs.rstrip.end_with?("/") && !VOID.include?(tag)
            end_tag(tag)
          end
        end
      else
        data(unescape(s.scan(/[^<]+/) || s.getch))
      end
    end
    flush
    self
  end

  private

  def attr?(attrs, name)
    attrs.match?(/(?:\A|\s)#{name}\s*=/)
  end

  def id_of(attrs)
    m = attrs.match(/(?:\A|\s)id\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/)
    m && unescape(m[1] || m[2] || m[3])
  end

  def blocky?(tag, closing: false)
    parent = if closing
      (@stack.size > 1) ? @stack[-2][0] : ""
    else
      @stack.empty? ? "" : @stack[-1][0]
    end
    BLOCK.include?(tag) || tag == "tr" || (tag == "span" && parent == "div")
  end

  def current_id(stack = @stack)
    stack.reverse_each { |_, i| return i if i }
    ""
  end

  def flush
    text = @buf.join
    @buf = []
    unless @cells.nil?
      text = text.gsub(/\s+/, " ").strip
      return if text.empty?
      # セルの中の <br> や <p> で区切られた分は、新しいセルにせず同じセルの別の段として足す
      # （段ごとに文へ割るので、句点で終わらない段が次の段とつながらない）
      if @in_cell && !@cells.empty?
        @cells[-1] << text
      else
        @cells << [text]
      end
      return
    end
    prefix = "[##{current_id}] "
    if @pre.positive?
      text.each_line { |line| @lines << prefix + line.rstrip unless line.strip.empty? }
      return
    end
    text = text.gsub(/\s+/, " ").strip
    return if text.empty?
    sentences(text).each { |sentence| @lines << prefix + sentence }
  end

  def start_tag(tag, attrs)
    if VOID.include?(tag)
      flush if tag == "br" && @skip.zero?
      return
    end
    if tag == "script" && @skip.zero?
      flush
      @script = attr?(attrs, "src") ? nil : []
      @skip += 1
      @stack << [tag, nil]
      return
    end
    if @skip.positive? || SKIP.include?(tag)
      @skip += 1
      @stack << [tag, nil]
      return
    end
    flush if blocky?(tag)
    if tag == "tr"
      @cells = []
    elsif %w[td th].include?(tag) && !@cells.nil?
      flush
      @cells << []
      @in_cell = true
    end
    @pre += 1 if tag == "pre"
    @stack << [tag, id_of(attrs)]
  end

  def end_tag(tag)
    return if VOID.include?(tag)
    return unless @stack.any? { |t, _| t == tag } # 対応しない閉じタグは無視する
    if tag == "script" && !@script.nil?
      prefix = "[##{current_id(@stack[0...-1])}] js| "
      @script.join.each_line { |line| @lines << prefix + line.strip unless line.strip.empty? }
      @script = nil
    end
    if @skip.positive?
      while (t, = @stack.pop)
        @skip -= 1
        break if t == tag
      end
      @skip = [@skip, 0].max
      return
    end
    if %w[td th].include?(tag) && !@cells.nil?
      flush
      @in_cell = false
    elsif tag == "tr" && !@cells.nil?
      flush
      row = @cells.reject(&:empty?)
      @cells = nil
      @in_cell = false
      # 表の行は 1 セルの中に何文も入るので、セルごと・文ごとに割る
      row.each_with_index do |segments, i|
        segments.flat_map { |segment| sentences(segment) }.each do |sentence|
          @lines << "[##{current_id}] |#{i + 1}| #{sentence}"
        end
      end
    elsif blocky?(tag, closing: true)
      flush
    end
    @pre -= 1 if tag == "pre"
    while (t, = @stack.pop)
      break if t == tag
    end
  end

  def data(text)
    if !@script.nil?
      @script << text
    elsif @skip.zero?
      @buf << text
    end
  end
end

def to_text(html)
  # read の保存ファイルは外枠とランタイムを含むので、本文だけにそろえる
  html = html.split("<!--claude-mermaid-runtime-begin", 2)[0]
  Extractor.new.feed(html).lines.join("\n") + "\n"
end

def write_text(html_path, out_path)
  text = to_text(File.read(html_path, encoding: "utf-8"))
  FileUtils.mkdir_p(File.dirname(out_path))
  File.write(out_path, text)
  puts "lines=#{text.count("\n")} bytes=#{text.bytesize} tool_version=#{TOOL_VERSION}"
  0
end

def write_diff(old_path, new_path, out_path, from:, to:, note: "")
  # Ruby に unified diff の標準ライブラリは無いので diff(1) を使う。見出しは Python 版（difflib）にそろえる
  out, status = Open3.capture2("diff", "-U1", "--label", from, "--label", to, old_path, new_path)
  out = out.force_encoding(Encoding::UTF_8) # ロケールが UTF-8 でないシェルでも日本語の行を扱えるように
  raise "diff failed: #{status}" if status.exitstatus > 1
  if status.exitstatus.zero?
    puts "no changes"
    return 3
  end
  body = out.lines.map { |l| l.start_with?("@@") ? l.sub(/ @@\s*$/, " @@\n") : l }
  head = "# #{from} -> #{to}#{"  #{note}" unless note.empty?}\n"
  FileUtils.mkdir_p(File.dirname(out_path)) # diffs/ が無い導入時でも書けるように
  File.write(out_path, head + body.join)
  changed = body.reject { |l| l.start_with?("+++", "---") }
  puts "+#{changed.count { |l| l.start_with?("+") }} -#{changed.count { |l| l.start_with?("-") }} bytes=#{(head + body.join).bytesize}"
  # changelog の sections に写す。id の無い行（ヘッダーやフッター）は空文字になる
  ids = changed.filter_map { |l| l[/\A[-+]\[#([^\]]*)\]/, 1] }.uniq
  puts "sections=#{JSON.generate(ids)}"
  0
end

def main(argv)
  cmd = argv.shift
  case cmd
  when "text"
    abort "usage: artifact_text.rb text <page.html> <out.txt>" unless argv.size == 2
    write_text(*argv)
  when "diff"
    opts = {note: ""}
    OptionParser.new do |o|
      o.on("--from V") { |v| opts[:from] = v }
      o.on("--to V") { |v| opts[:to] = v }
      o.on("--note N") { |v| opts[:note] = v }
    end.parse!(argv)
    abort "usage: artifact_text.rb diff <old> <new> <out> --from V --to V [--note N]" unless argv.size == 3 && opts[:from] && opts[:to]
    write_diff(*argv, **opts)
  else
    abort "usage: artifact_text.rb text|diff ..."
  end
end

# ロケールが UTF-8 でないシェルでは引数（--note の日本語など）が UTF-8 として扱われない
exit main(ARGV.map { |a| a.dup.force_encoding(Encoding::UTF_8) })
