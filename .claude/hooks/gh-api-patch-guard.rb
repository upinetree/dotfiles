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
#
# 入力 : stdin に PreToolUse の JSON（.tool_input.command を使う）
# 出力 : 確認に回すときだけ permissionDecision=ask を JSON で stdout。それ以外は無出力 exit 0
#        （無出力なら settings の allow `Bash(gh api:*)` で通る）。

require "json"
require "shellwords"

ALLOWED_ENDPOINT = %r{\A/?repos/[^/]+/[^/]+/(issues/\d+|pulls/\d+|issues/comments/\d+)\z}
# macOS では /tmp が /private/tmp への symlink なので、realpath で比べる
SCRATCHPAD_ROOT = "/private/tmp/claude-#{Process.uid}/"
# gh のプレースホルダー。シェルは , か .. を含まない { } を展開しないが、確実に安全なものだけ許す
GH_PLACEHOLDER = /\{(owner|repo|branch)\}/
RAW_FIELD_FLAGS = %w[-f --raw-field].freeze
# -F / --field は値が @ で始まるとファイル（@- は stdin）から読む
FILE_FIELD_FLAGS = %w[-F --field].freeze
FIELD_FLAGS = (RAW_FIELD_FLAGS + FILE_FIELD_FLAGS).freeze
METHOD_FLAGS = %w[-X --method].freeze
# gh api の値を取るフラグと値を取らないフラグ。ここに無いフラグは読み違えうるので確認に回す
VALUE_FLAGS = (FIELD_FLAGS + METHOD_FLAGS + %w[-H --header --jq -q -t --template --hostname --cache -p --preview --input]).freeze
BOOL_FLAGS = %w[-i --include --paginate --slurp --silent --verbose].freeze

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

# method やフィールドの書き方は引用符やフラグのくっつけ方で何通りもあるので、ここでは粗く拾い、
# 本当の中身は parse で語に分けてから決める
def needs_check?(cmd)
  # 引用符とバックスラッシュを落として g"h" や PAT""CH のような分け書きも拾う
  plain = cmd.delete("'\"\\")
  # gh-api-patch-guard.rb のようなファイル名の一部を gh と読まないよう、前後のハイフンを除く。
  # 直後が issue・pr のような英字だけのサブコマンドなら gh api ではないので対象外にする。
  # gh ap? や gh $SUB のように api を展開で隠す形は、英字以外を含むので対象に残る
  subcommands = plain.scan(/(?<![\w-])gh(?![\w-])\s*(\S*)/).flatten
  return false if subcommands.all? { |s| s.match?(/\A[a-z][a-z-]*\z/) && s != "api" }

  # method を変数や置換で渡す形、PAT?H や {-,-}XPAT{CH,CH} のようにグロブやブレース展開で
  # 組み立てる形は文字列から読めないので、それも候補にする
  return true if unquoted_specials(cmd).intersect?(EXPANSION_CHARS)

  # :// は、フラグを付けない GET でも URL のエンドポイントで GitHub 以外へ送れるため。
  # パイプの先の grep "https://..." のような別コマンドの URL を拾わないよう、gh api と同じ
  # 単純コマンドの中だけを見る。gh api は stdin から URL を読まないので、URL を外から渡すには
  # cat x | xargs gh api のように gh を別のコマンドから呼ぶしかない。gh が単純コマンドの先頭の
  # 語でなければ、その単純コマンドに :// が無くても候補にする
  return true if simple_commands(cmd).any? do |seg|
    s = seg.delete("'\"\\")
    s.match?(/(?<![\w-])gh(?![\w-])/) && s.match?(/\bapi\b/) &&
      (s.include?("://") || s.strip.split(/\s+/).first != "gh")
  end

  # -iXDELETE のように値を取らない短いフラグと -X・-f・-F をまとめて書く形もある。
  # 空白の直後に限るのは、my-fork のようなリポジトリ名の -f を拾わないため
  plain.match?(/\bapi\b/) &&
    (plain.match?(/patch/i) || plain.match?(/(?<=\s)(-[a-zA-Z]*[XfF]|--(method|field|raw-field|input|hostname)\b)/))
end

# 引用符の外の ; & | などでコマンド文字列を区切る
def simple_commands(cmd)
  segments = [+""]
  state = nil
  cmd.each_char do |c|
    if state.nil? && OPERATOR_CHARS.include?(c)
      segments << +""
      next
    end
    segments.last << c
    if state.nil?
      state = c if ["'", '"'].include?(c)
    elsif c == state
      state = nil
    end
  end
  segments
end

# 引用符の外でシェルが展開する文字。zsh ではブレース展開やグロブで語が書き換わる。
# { } は gh のプレースホルダーを除くため、unquoted_specials で別に見る
EXPANSION_CHARS = ["`", "$", "\\", "{", "}", "*", "?", "[", "]", "~", "!", "#"].freeze
# 引用符の外でコマンドを連結・置換・リダイレクトする文字
OPERATOR_CHARS = [";", "&", "|", "<", ">", "\n", "(", ")"].freeze

# 引用符の状態を追いながら、シェルが特別に扱う文字のうち引用符の外（または二重引用符の
# 中の展開）にあるものを集める。正規表現で引用符を落とすと "it's" のような組み合わせで
# 読み違える。閉じていない引用符は "'" を含めて知らせる
def unquoted_specials(cmd)
  found = []
  outside = +""
  state = nil
  cmd.each_char do |c|
    case state
    when "'" then state = nil if c == "'"
    when '"'
      found << c if ["$", "`", "\\"].include?(c)
      state = nil if c == '"'
    else
      if ["'", '"'].include?(c)
        state = c
      else
        outside << c
        found << c if (EXPANSION_CHARS - ["{", "}"]).include?(c) || OPERATOR_CHARS.include?(c)
      end
    end
  end
  found << "'" unless state.nil?
  # repos/{owner}/{repo} のような gh のプレースホルダーだけを除いて、残る { } を数える
  found.concat(outside.gsub(GH_PLACEHOLDER, "").scan(/[{}]/))
  found
end

def shell_special?(cmd)
  unquoted_specials(cmd).any?
end

# 単独の `gh api ...` を語に分け、method・エンドポイント・フィールド・--input と --hostname の
# 有無を取り出す。知らないフラグや 2 つ目の位置引数があれば Unreadable を投げる
def parse(cmd)
  words = Shellwords.split(cmd)
  raise Unreadable, "gh api で始まっていない" unless words[0] == "gh" && words[1] == "api"

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

begin
  data = JSON.parse($stdin.read.force_encoding(Encoding::UTF_8).scrub)
  cmd = data.dig("tool_input", "command").to_s
  exit 0 unless needs_check?(cmd)

  # パイプ・連結・置換・エスケープ・ブレース展開・グロブを含む形は、語に分けても実際に実行される形と一致する保証が無い
  ask("書き込みを含みうる gh api のうち、展開・連結・閉じていない引用符を含むコマンドは確認する") if shell_special?(cmd)

  begin
    req = parse(cmd)
  rescue Unreadable, ArgumentError => e
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
    exit 0
  end

  exit 0 if ["GET", "HEAD"].include?(method)
  ask("gh api の #{method} は確認する") unless method == "PATCH"

  ask("PATCH の対象が issue・PR の本文かコメントではない（#{req[:endpoint]}）") unless req[:endpoint].match?(ALLOWED_ENDPOINT)
  ask("--input で渡す中身は確かめられない") if req[:input]
  ask("body 以外のフィールドを送っている（#{req[:fields].map { |f| f[:name] }.join(", ")}）") unless req[:fields].map { |f| f[:name] } == ["body"]

  exit 0
rescue SystemExit
  raise
rescue
  # 判定に失敗したら通さずに確認へ倒す（以前の ask ルールと同じ側に失敗させる）
  ask("gh-api-patch-guard の判定に失敗した")
end
