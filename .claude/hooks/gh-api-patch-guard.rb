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
# 受け持つ範囲: allow `Bash(gh api:*)` に一致して auto mode の分類器を通らない単純コマンド、
# つまり gh api として実行されるものだけを判定する。; & | 改行で区切った単純コマンドを語に
# 分け、gh と api が別の語として並ぶものを、その単純コマンドの中で判定する。ほかの単純
# コマンドは Claude Code が別に allow ルールか分類器で判定するので見ない。bash -c '...'・
# eval・$G api のように gh を文字列や変数で隠す形も allow ルールに一致しないので、分類器に任せる。
#
# シェルの構文（heredoc・コメント・エスケープ・引用符の付いたリダイレクトなど）を真似て
# 読み分けると、真似きれなかった所でシェルとの解釈がずれ、実行される gh api を見落とす。
# そのため細かくは読み分けず、引用符を外した全文に現れる gh api の数と、判定できた gh api の
# 数が合わなければ確認に回す。コミットメッセージや heredoc の本文に gh api と書いただけの
# コマンドにも確認が出るが、見落とすより安全な側に倒す。
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
#   - gh api の単純コマンドの中の展開（-X $M、PAT?H、$(...)、プロセス置換）と、gh を
#     xargs などから呼ぶ形。実行される引数を文字列から読めない
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

# 引用符の外でシェルが展開する文字。zsh ではブレース展開やグロブで語が書き換わる。
# { } は gh のプレースホルダーを除くため、unquoted_specials で別に見る
EXPANSION_CHARS = ["`", "$", "\\", "{", "}", "*", "?", "[", "]", "~", "!", "#"].freeze
# 引用符の外でコマンドを連結・置換・リダイレクトする文字
OPERATOR_CHARS = [";", "&", "|", "<", ">", "\n", "(", ")"].freeze
# gh api の単純コマンドの中にあれば確認に回す文字。リダイレクトの < > は語から外して読むので含めない
UNREADABLE_CHARS = (EXPANSION_CHARS + ["(", ")", "'"]).freeze
# 単純コマンドの区切り。リダイレクトとプロセス置換の後ろも同じコマンドの語なので < > ( ) では区切らない
SEPARATOR_CHARS = [";", "&", "|", "\n"].freeze
# gh の前に置いても、gh が実行されるコマンドであることが変わらない語
KEYWORDS = %w[do then else elif ! {].freeze
REDIRECTION_OP = /\d*(>\||&>>?|>>?|>&|<&|<)/
REDIRECTION = /\A#{REDIRECTION_OP}/
# シェルが語の区切りにしない制御文字。Shellwords は区切りにするので、語の読み方がずれる
CONTROL_CHARS = /[\x00-\x08\x0b-\x0d\x0e-\x1f\x7f]/

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

# gh の直後の語が api か、ap? や $SUB のように展開で api になりうるか。全文の数え上げと
# 単純コマンドの語の両方で同じ判定を使い、照合の数を揃える
def api_like?(token)
  token.match?(/\Aapi\b/) || token.match?(/[$`{}*?\[\]]/)
end

# 引用符とバックスラッシュを落とした全文に現れる gh api の数。g"h" api のような分け書きも
# 数える。gh-api-patch-guard.rb のようなファイル名の一部を gh と読まないよう、前後のハイフンを除く。
# 直後の語は先読みで見る。読み進めると echo gh;gh api の ;gh を直後の語として食い、後ろの gh を数え落とす
def gh_api_count(plain)
  plain.scan(/(?<![\w-])gh(?![\w-])(?=\s*(\S*))/).flatten.count { |t| api_like?(t) }
end

# 引用符の外の ; & | と改行で単純コマンドに区切る。2>&1 や &> の & と >| の | はリダイレクトなので
# 区切らない。\; や \' はエスケープされた文字なので、区切りにも引用符の始まりにもしない
def simple_commands(cmd)
  segments = [+""]
  state = nil
  escaped = false
  cmd.each_char.with_index do |c, i|
    if escaped
      segments.last << c
      escaped = false
      next
    end
    if state.nil? && SEPARATOR_CHARS.include?(c) &&
        !(c == "&" && (["<", ">"].include?(cmd[i - 1]) || cmd[i + 1] == ">")) &&
        !(c == "|" && cmd[i - 1] == ">")
      segments << +""
      next
    end
    segments.last << c
    if state.nil?
      if c == "\\"
        escaped = true
      elsif ["'", '"'].include?(c)
        state = c
      end
    elsif state == '"' && c == "\\"
      escaped = true
    elsif c == state
      state = nil
    end
  end
  segments
end

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

# 単純コマンドの語のうち、gh api として実行されうる gh の位置をすべて返す。$(gh や (gh の
# ように置換やサブシェルの中で呼ぶ gh と、{gh,} のように展開で gh になりうる語も数える
def gh_api_indexes(words)
  words.each_index.select do |i|
    nxt = words[i + 1]
    next false if nxt.nil?

    if words[i].match?(%r{(\A|[^\w-])gh\z})
      api_like?(nxt)
    else
      # grep の ".*" や python -c のコードのような長い語を拾わないよう、展開で gh になりうる
      # 短いトークンで、直後が文字どおり api のときだけ数える
      nxt == "api" && words[i].match?(/\A[\w{},*?\[\]\/.-]+\z/) && words[i].include?("g") && words[i].match?(/[{}*?\[]/)
    end
  end
end

# 引用符の外にある文字だけをつないだ文字列
def outside_quotes(cmd)
  outside = +""
  state = nil
  cmd.each_char do |c|
    if state
      state = nil if c == state
    elsif ["'", '"'].include?(c)
      state = c
    else
      outside << c
    end
  end
  outside
end

def strip_redirections(words)
  out = []
  skip = false
  words.each do |w|
    if skip
      skip = false
    elsif (m = w.match(REDIRECTION))
      skip = m[0] == w
    else
      out << w
    end
  end
  out
end

# `gh api ...` の語を読み、method・エンドポイント・フィールド・--input と --hostname の
# 有無を取り出す。知らないフラグや 2 つ目の位置引数があれば Unreadable を投げる
def parse(words)
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

# 1 つの単純コマンドの中の gh api を判定し、見つけた数を返す。確認に回すときは ask で終了する
def judge(segment)
  words = Shellwords.split(segment)
  indexes = gh_api_indexes(words)
  return 0 if indexes.empty?

  idx = indexes.first
  ask("gh を別のコマンドから呼んでいる（#{words[idx - 1]}）") unless indexes.size == 1 && words[0...idx].all? { |w| KEYWORDS.include?(w) }
  # 展開・置換・プロセス置換を含む形は、語に分けても実際に実行される引数と一致する保証が無い
  ask("gh api の中に展開・置換・閉じていない引用符がある") if unquoted_specials(segment).intersect?(UNREADABLE_CHARS)
  # Shellwords は引用符を外すので、--jq '>' のように引用符で囲んだ > もリダイレクトに見え、読み飛ばすと
  # 後ろのフラグと値の組み合わせがずれる。引用符の外のリダイレクト演算子と数が合わなければ確認に回す
  redirect_words = words[idx..].count { |w| w.match?(REDIRECTION) }
  ask("gh api のリダイレクトを読み取れなかった") if redirect_words != outside_quotes(segment).scan(REDIRECTION_OP).size ||
    words.last.to_s.match?(/#{REDIRECTION}\z/o)

  begin
    req = parse(strip_redirections(words[idx..]))
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
    return 1
  end

  return 1 if ["GET", "HEAD"].include?(method)
  ask("gh api の #{method} は確認する") unless method == "PATCH"

  ask("PATCH の対象が issue・PR の本文かコメントではない（#{req[:endpoint]}）") unless req[:endpoint].match?(ALLOWED_ENDPOINT)
  ask("--input で渡す中身は確かめられない") if req[:input]
  ask("body 以外のフィールドを送っている（#{req[:fields].map { |f| f[:name] }.join(", ")}）") unless req[:fields].map { |f| f[:name] } == ["body"]
  1
rescue ArgumentError
  # 引用符が閉じていない単純コマンドは語に分けられない。そこに gh api があれば、全文との照合で確認に回る
  0
end

begin
  data = JSON.parse($stdin.read.force_encoding(Encoding::UTF_8).scrub)
  # 行継続はシェルが語を読む前に消すので、先に消す。残すと g\<改行>h api の gh を数え落とす。
  # ただしコメントや引用符の中の \<改行> はシェルが消さないので、一律に消すと # x\<改行>gh api が
  # xgh api になって数え落とす。消す前と後の両方で数え、多いほうと照合する
  raw = data.dig("tool_input", "command").to_s
  cmd = raw.gsub("\\\n", "")
  expected = [gh_api_count(raw.delete("'\"\\")), gh_api_count(cmd.delete("'\"\\"))].max
  exit 0 if expected.zero?

  ask("gh api のコマンドに制御文字がある") if cmd.match?(CONTROL_CHARS)

  judged = simple_commands(cmd).sum { |segment| judge(segment) }
  # コメント・heredoc・エスケープなどで区切りや語の読み方がシェルとずれると、実行される gh api を
  # 単純コマンドの中に見つけられない。見つけた数が全文より少なければ、隠れた gh api があるとみなす
  ask("gh api の書き方を読み取れなかった（全文に #{expected} 個、判定できたのは #{judged} 個）") if judged < expected
  exit 0
rescue SystemExit
  raise
rescue
  # 判定に失敗したら通さずに確認へ倒す（以前の ask ルールと同じ側に失敗させる）
  ask("gh-api-patch-guard の判定に失敗した")
end
