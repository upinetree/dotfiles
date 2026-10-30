#!/usr/bin/env ruby
# frozen_string_literal: true

# PreToolUse(Bash) hook: `gh api` の書き込みと、ローカルのファイルを外へ送りうる形に確認を出す。
# PATCH のうち issue / PR の本文とコメントの本文の書き換えは確認なしで通す。
#
# 背景: 以前は settings.json の ask ルール `Bash(gh api *-X PATCH*)` で PATCH を一律に
# 確認していた。ask ルールは allow ルールより先に評価され、具体的な allow でも
# フックの allow でも上書きできない（permissions の "Manage permissions" と
# "Extend permissions with hooks"）。除外を書く構文も無いため、ask ルールを外して
# 判定をこのフックに移した。フックが返す ask は auto mode でも確認を出す。
#
# 受け持つ範囲: allow `Bash(gh api:*)` に一致して auto mode の分類器を通らないもの、つまり
# gh api として実行されるコマンド呼び出しだけを判定する。コミットメッセージや heredoc の本文に
# 書いた gh api は実行されないので見ない。bash -c '...'・eval・$G api のように gh を文字列や
# 変数で隠す形は allow ルールに一致しないので、分類器に任せる。
#
# コマンドの読み分けは shfmt の構文木に任せる。heredoc・コメント・行継続・引用符をこのフックで
# 真似て読むと、真似きれなかった所でシェルとの解釈がずれ、実行される gh api を見落とし続けた。
# shfmt が無い・構文を読めない（zsh だけの書き方など）ときは、gh api らしい文字列があれば確認に回す。
#
# 通すもの:
#   - GET・HEAD（-X GET にフィールドを付けた検索も含む）
#   - gh api graphql の読み取り。GraphQL は書き込みに mutation キーワードが要るので、
#     クエリにその語が無ければ読み取りとみなす
#   - 次のエンドポイントへの PATCH で、送るフィールドが body だけのもの
#       repos/<o>/<r>/issues/<n>            issue の本文
#       repos/<o>/<r>/pulls/<n>             PR の本文
#       repos/<o>/<r>/issues/comments/<id>  issue・PR の会話のコメント
#     body だけに限るのは、同じエンドポイントで state・base・assignees なども変えられるため
#
# 確認に回すもの:
#   - POST・PUT・DELETE。settings.json の ask ルール（`Bash(gh api *-X DELETE*)` など）にも
#     残しているが、文字列の一致なので -X=DELETE のような書き方を見落とす。-X を書かずに
#     フィールドを渡すと gh は POST にするので、REST へのその形も含める
#   - -F key=@<path> が Claude Code の scratchpad（/private/tmp/claude-<uid>/）の外のファイルを
#     読む形。allow `Bash(gh api:*)` のもとでは、~/.ssh などの中身を issue に書き込む流出の
#     経路になる。本文を長く書くときは scratchpad にファイルを置いて送る。共有の /tmp を
#     許さないのは、ほかのユーザーが symlink を仕込めるため。確認してから gh が読むまでに
#     自分の別のプロセスがファイルを差し替える形は防げない
#   - gh api graphql の query をファイルで渡す形。読み取りのクエリで確認を通したあと、
#     mutation に差し替えられる
#   - --hostname と URL のエンドポイント。GitHub 以外のホストへ送れる
#   - --input。中身を確かめられない
#   - gh api の引数の展開（-X $M、PAT?H、{PATCH,}、$(...)）と、gh を xargs などから呼ぶ形・
#     GH_HOST= のような代入を前に置く形。実行される引数や送り先を文字列から読めない
#
# 入力 : stdin に PreToolUse の JSON（.tool_input.command を使う）
# 出力 : 確認に回すときだけ permissionDecision=ask を JSON で stdout。それ以外は無出力 exit 0
#        （無出力なら settings の allow `Bash(gh api:*)` で通る）。

require "json"
require "open3"

ALLOWED_ENDPOINT = %r{\A/?repos/[^/]+/[^/]+/(issues/\d+|pulls/\d+|issues/comments/\d+)\z}
# macOS では /tmp が /private/tmp への symlink なので、realpath で比べる
SCRATCHPAD_ROOT = "/private/tmp/claude-#{Process.uid}/"
# gh のプレースホルダー。シェルは , か .. を含まない { } を展開しないが、確実に安全なものだけ許す
GH_PLACEHOLDER = /\{(owner|repo|branch)\}/
# 引用符の外にあると zsh がブレース展開・グロブ・チルダ展開で語を書き換えうる文字
GLOB_CHARS = /[{}*?\[\]~]/
RAW_FIELD_FLAGS = %w[-f --raw-field].freeze
# -F / --field は値が @ で始まるとファイル（@- は stdin）から読む
FILE_FIELD_FLAGS = %w[-F --field].freeze
FIELD_FLAGS = (RAW_FIELD_FLAGS + FILE_FIELD_FLAGS).freeze
METHOD_FLAGS = %w[-X --method].freeze
# gh api の値を取るフラグと値を取らないフラグ。ここに無いフラグは読み違えうるので確認に回す
VALUE_FLAGS = (FIELD_FLAGS + METHOD_FLAGS + %w[-H --header --jq -q -t --template --hostname --cache -p --preview --input]).freeze
BOOL_FLAGS = %w[-i --include --paginate --slurp --silent --verbose].freeze
# hook は GUI から起動した Claude Code の PATH で動くので、Homebrew の既定の場所も探す
SHFMT_CANDIDATES = ["shfmt", "/opt/homebrew/bin/shfmt", "/usr/local/bin/shfmt", "/home/linuxbrew/.linuxbrew/bin/shfmt"].freeze

class Unreadable < StandardError; end

def ask(reason)
  puts JSON.generate(
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: reason
    }
  )
  exit 0
end

# gh api を含みうるかの粗い判定。含まなければ shfmt を起動せずに通す。引用符とバックスラッシュを
# 落として g"h" api も拾い、行継続（g\<改行>h）を消した形でも見る。ファイル名の gh-api-... は数えない
def mentions_gh_api?(cmd)
  [cmd, cmd.gsub("\\\n", "")].any? do |text|
    text.delete("'\"\\").scan(/(?<![\w-])gh(?![\w-])(?=\s*(\S*))/).flatten.any? { |t| t.match?(/\Aapi\b|[$`{}*?\[\]]/) }
  end
end

def shfmt_ast(cmd)
  SHFMT_CANDIDATES.each do |bin|
    out, err, status = Open3.capture3(bin, "--to-json", "-ln", "bash", stdin_data: cmd)
    return JSON.parse(out) if status.success?

    raise Unreadable, "構文を読めなかった（#{err.lines.first.to_s.strip}）"
  rescue Errno::ENOENT
    next
  end
  raise Unreadable, "shfmt が見つからない"
end

def each_call(node, &block)
  case node
  when Hash
    yield node if node["Type"] == "CallExpr"
    node.each_value { |v| each_call(v, &block) }
  when Array
    node.each { |v| each_call(v, &block) }
  end
end

# 語の部品を、シェルが渡す文字列にする。変数展開・置換・$'...' のように文字列から値が決まらない
# 部品があれば dynamic、引用符の外にグロブ・ブレース展開・=cmd 展開になりうる文字があれば glob
def read_word(word)
  text = +""
  unquoted = +""
  dynamic = false
  word.fetch("Parts", []).each do |part|
    case part["Type"]
    when "Lit"
      # shfmt は Lit の値にバックスラッシュを残すので、シェルと同じく外す。残すと g\h api を
      # gh と読めず見落とす。グロブの判定は外す前の値で見て、\* なども確認に回る側に倒す
      text << part["Value"].gsub("\\\n", "").gsub(/\\(.)/m, '\1')
      unquoted << part["Value"]
    when "SglQuoted"
      dynamic = true if part["Dollar"]
      text << part["Value"]
    when "DblQuoted"
      part.fetch("Parts", []).each do |inner|
        # 二重引用符の中のバックスラッシュは $ ` " \ 改行の前でだけ外れる
        if inner["Type"] == "Lit"
          text << inner["Value"].gsub(/\\([$`"\\\n])/) { ($1 == "\n") ? "" : $1 }
        else
          dynamic = true
        end
      end
    else
      dynamic = true
    end
  end
  glob = unquoted.gsub(GH_PLACEHOLDER, "").match?(GLOB_CHARS) || unquoted.start_with?("=")
  {text: text, dynamic: dynamic, glob: glob}
end

# gh の位置。$G のように値の決まらない語は、allow ルールにも一致しないので分類器に任せる。
# {gh,} や =gh のように展開で gh になりうる語は数える。~/.claude/settings.json のような
# パスまで拾わないよう、gh の文字と展開の記号だけでできた語に限る
def gh_word?(word)
  return false if word[:dynamic]

  word[:text].match?(%r{(\A|/)gh\z}) || (word[:glob] && word[:text].match?(/\A[gh{},*?\[\]=]*g[gh{},*?\[\]=]*\z/))
end

def api_like?(word)
  return false if word.nil?

  word[:text] == "api" || word[:dynamic] || (word[:glob] && word[:text].match?(/\A[api{},*?\[\]]+\z/))
end

# `gh api ...` の語を読み、method・エンドポイント・フィールド・--input と --hostname の
# 有無を取り出す。知らないフラグや 2 つ目の位置引数があれば Unreadable を投げる
def parse(words)
  method = nil
  endpoint = nil
  fields = []
  input = false
  hostname = false
  i = 2
  while i < words.size
    w = words[i]
    flag, value =
      if (m = w.match(/\A(--[a-z-]+)=(.*)\z/m)) then [m[1], m[2]]
      # pflag はくっつけた短いフラグの値の先頭の = を 1 つ落とす（-X=PATCH は PATCH になる）
      elsif (m = w.match(/\A(-[a-zA-Z])=?(.+)\z/m)) then [m[1], m[2]]
      elsif w.start_with?("-") then [w, nil]
      end

    if flag.nil?
      raise Unreadable, "位置引数が 2 つある（#{endpoint} と #{w}）" if endpoint
      endpoint = w
    elsif VALUE_FLAGS.include?(flag)
      if value.nil?
        i += 1
        raise Unreadable, "#{flag} の値が無い" if i >= words.size
        value = words[i]
      end
      if METHOD_FLAGS.include?(flag)
        # 英字だけでない method は読み違えている見込みが高いので、書き込みでないと決めつけない
        raise Unreadable, "method を読み取れない（#{value}）" unless value.match?(/\A[A-Za-z]+\z/)
        method = value
      end
      if FIELD_FLAGS.include?(flag)
        name, val = value.split("=", 2)
        file = val[1..] if FILE_FIELD_FLAGS.include?(flag) && val.to_s.start_with?("@")
        fields << {name: name, value: val.to_s, file: file}
      end
      input = true if flag == "--input"
      hostname = true if flag == "--hostname"
    elsif BOOL_FLAGS.include?(flag) && value.nil?
      nil
    else
      raise Unreadable, "知らないフラグ（#{w}）"
    end
    i += 1
  end
  {method: method.to_s.upcase, endpoint: endpoint.to_s, fields: fields, input: input, hostname: hostname}
end

# 相対パスは cwd 次第で、symlink は scratchpad の外を指しうるので、絶対パスを realpath にして比べる。
# scratchpad の根が自分だけのもの（所有者が自分で、ほかの人に権限が無い）でなければ、どれも許さない
def allowed_file?(path)
  return false unless path.start_with?("/")

  root = File.stat(SCRATCHPAD_ROOT)
  return false unless root.directory? && root.uid == Process.uid && (root.mode & 0o077).zero?

  real = File.realpath(path)
  real.start_with?(SCRATCHPAD_ROOT) && File.stat(real).file?
rescue SystemCallError
  false
end

# query を 2 つ渡して後ろに mutation を置く形を見落とさないよう、query がちょうど 1 つのときだけ
# 読む。gh 2.103 は query の重複や query[x] を実行前にエラーにするが、その挙動には頼らない。
# ファイルで渡す query は、ここで読んだあと gh が読むまでに差し替えられるので読まない
def graphql_query(fields)
  queries = fields.select { |f| f[:name] == "query" || f[:name].to_s.start_with?("query[") }
  return nil unless queries.size == 1 && queries[0][:name] == "query" && queries[0][:file].nil?

  queries[0][:value]
end

# 1 つのコマンド呼び出しを判定する。gh api でなければ何もせず、確認に回すときは ask で終了する
def judge(call)
  words = call.fetch("Args", []).map { |w| read_word(w) }
  idx = words.each_index.find { |i| gh_word?(words[i]) && api_like?(words[i + 1]) }
  return if idx.nil?

  ask("gh を別のコマンドから呼んでいる（#{words[idx - 1][:text]}）") unless idx.zero?
  ask("gh api の前に代入がある") if call["Assigns"]&.any?
  ask("gh api の引数に展開・置換がある") if words.any? { |w| w[:dynamic] || w[:glob] }

  begin
    req = parse(words.map { |w| w[:text] })
  rescue Unreadable => e
    ask("gh api の形を読み取れなかった（#{e.message}）")
  end

  ask("--hostname で GitHub 以外へ送りうる") if req[:hostname]
  ask("エンドポイントが URL で、GitHub 以外へ送りうる（#{req[:endpoint]}）") if req[:endpoint].include?("://")
  outside_files = req[:fields].filter_map { |f| f[:file] }.reject { |path| allowed_file?(path) }
  ask("scratchpad の外のファイル（または stdin）を送る（#{outside_files.join(", ")}）") if outside_files.any?

  method = req[:method]
  method = (req[:fields].any? || req[:input]) ? "POST" : "GET" if method.empty?

  if req[:endpoint].delete_prefix("/") == "graphql"
    ask("gh api graphql の --input は中身を確かめられない") if req[:input]
    query = graphql_query(req[:fields])
    ask("gh api graphql の query が無い・1 つに定まらない・ファイルで渡されている") if query.nil?
    ask("gh api graphql の mutation は確認する") if query.match?(/\bmutation\b/)
    return
  end

  return if ["GET", "HEAD"].include?(method)
  ask("gh api の #{method} は確認する") unless method == "PATCH"

  ask("PATCH の対象が issue・PR の本文かコメントではない（#{req[:endpoint]}）") unless req[:endpoint].match?(ALLOWED_ENDPOINT)
  ask("--input で渡す中身は確かめられない") if req[:input]
  ask("body 以外のフィールドを送っている（#{req[:fields].map { |f| f[:name] }.join(", ")}）") unless req[:fields].map { |f| f[:name] } == ["body"]
end

begin
  data = JSON.parse($stdin.read.force_encoding(Encoding::UTF_8).scrub)
  cmd = data.dig("tool_input", "command").to_s
  exit 0 unless mentions_gh_api?(cmd)

  begin
    ast = shfmt_ast(cmd)
  rescue Unreadable => e
    ask("gh api を含むコマンドの#{e.message}")
  end
  each_call(ast) { |call| judge(call) }
  exit 0
rescue SystemExit
  raise
rescue
  # 判定に失敗したら通さずに確認へ倒す（以前の ask ルールと同じ側に失敗させる）
  ask("gh-api-patch-guard の判定に失敗した")
end
