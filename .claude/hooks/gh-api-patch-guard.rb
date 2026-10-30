#!/usr/bin/env ruby
# frozen_string_literal: true

# PreToolUse(Bash) hook: `gh api` の PATCH を、issue / PR の本文とコメントの本文の
# 書き換えだけ確認なしで通し、それ以外は確認を出す。POST・PUT・DELETE も確認を出す。
#
# 背景: 以前は settings.json の ask ルール `Bash(gh api *-X PATCH*)` で PATCH を一律に
# 確認していた。ask ルールは allow ルールより先に評価され、具体的な allow でも
# フックの allow でも上書きできない（permissions の "Manage permissions" と
# "Extend permissions with hooks"）。除外を書く構文も無いため、ask ルールを外して
# 判定をこのフックに移した。フックが返す ask は auto mode でも確認を出す。
#
# 通すもの: 次のエンドポイントへの PATCH で、送るフィールドが body だけのもの。
#   repos/<o>/<r>/issues/<n>            issue の本文
#   repos/<o>/<r>/pulls/<n>             PR の本文
#   repos/<o>/<r>/issues/comments/<id>  issue・PR の会話のコメント
# body だけに限るのは、同じエンドポイントで state・base・assignees なども変えられるため。
# --input で JSON を渡す形は中身を見られないので確認に回す。
#
# POST・PUT・DELETE は settings.json の ask ルール（`Bash(gh api *-X DELETE*)` など）にも
# 残しているが、文字列の一致なので -X=DELETE や -XDELETE のような書き方を見落とす。
# このフックは語に分けて読むので、その書き方もここで確認に回す。-X を書かずにフィールドを
# 渡すと gh は POST にするが、gh api graphql の読み取りもその形なので対象にしていない。
#
# 入力 : stdin に PreToolUse の JSON（.tool_input.command を使う）
# 出力 : 確認に回すときだけ permissionDecision=ask を JSON で stdout。それ以外は無出力 exit 0
#        （無出力なら settings の allow `Bash(gh api:*)` で通る）。

require "json"
require "shellwords"

ALLOWED_ENDPOINT = %r{\A/?repos/[^/]+/[^/]+/(issues/\d+|pulls/\d+|issues/comments/\d+)\z}
FIELD_FLAGS = %w[-f -F --field --raw-field].freeze
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

# method の書き方は引用符やフラグのくっつけ方で何通りもあるので、ここでは粗く拾い、
# 本当の method は parse で語に分けてから決める
def maybe_write?(cmd)
  # 引用符とバックスラッシュを落として g"h" や PAT""CH のような分け書きも拾う
  plain = cmd.delete("'\"\\")
  # gh-api-patch-guard.rb のようなファイル名の一部を gh と読まないよう、前後のハイフンを除く
  return false unless plain.match?(/(?<![\w-])gh(?![\w-])/)

  # method を変数や置換で渡す形、PAT?H や {-,-}XPAT{CH,CH} のようにグロブやブレース展開で
  # 組み立てる形は文字列から読めないので、それも書き込みの候補にする
  return true if unquoted_specials(cmd).intersect?(EXPANSION_CHARS)

  # -iXDELETE のように値を取らない短いフラグと -X をまとめて書く形もある
  plain.match?(/\bapi\b/) && (plain.match?(/patch/i) || plain.match?(/(?<!\w)-[a-zA-Z]*X|--method/))
end

# 引用符の外でシェルが展開する文字。zsh ではブレース展開やグロブで語が書き換わる
EXPANSION_CHARS = ["`", "$", "\\", "{", "}", "*", "?", "[", "]", "~", "!", "#"].freeze
# 引用符の外でコマンドを連結・置換・リダイレクトする文字
OPERATOR_CHARS = [";", "&", "|", "<", ">", "\n", "(", ")"].freeze

# 引用符の状態を追いながら、シェルが特別に扱う文字のうち引用符の外（または二重引用符の
# 中の展開）にあるものを集める。正規表現で引用符を落とすと "it's" のような組み合わせで
# 読み違える。閉じていない引用符は "'" を含めて知らせる
def unquoted_specials(cmd)
  found = []
  state = nil
  cmd.each_char do |c|
    case state
    when "'" then state = nil if c == "'"
    when '"'
      found << c if ["$", "`", "\\"].include?(c)
      state = nil if c == '"'
    else
      found << c if EXPANSION_CHARS.include?(c) || OPERATOR_CHARS.include?(c)
      state = c if ["'", '"'].include?(c)
    end
  end
  found << "'" unless state.nil?
  found
end

def shell_special?(cmd)
  unquoted_specials(cmd).any?
end

# 単独の `gh api ...` を語に分け、method・エンドポイント・フィールド名・--input の有無を取り出す。
# 知らないフラグや 2 つ目の位置引数があれば Unreadable を投げる
def parse(cmd)
  words = Shellwords.split(cmd)
  raise Unreadable, "gh api で始まっていない" unless words[0] == "gh" && words[1] == "api"

  method = nil
  endpoint = nil
  fields = []
  input = false
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
      fields << value.split("=", 2).first if FIELD_FLAGS.include?(flag)
      input = true if flag == "--input"
    elsif BOOL_FLAGS.include?(flag) && value.nil?
      nil
    else
      raise Unreadable, "知らないフラグ（#{w}）"
    end
    i += 1
  end
  {method: method.to_s.upcase, endpoint: endpoint.to_s, fields: fields, input: input}
end

begin
  data = JSON.parse($stdin.read.force_encoding(Encoding::UTF_8).scrub)
  cmd = data.dig("tool_input", "command").to_s
  exit 0 unless maybe_write?(cmd)

  # パイプ・連結・置換・エスケープ・ブレース展開・グロブを含む形は、語に分けても実際に実行される形と一致する保証が無い
  ask("書き込みを含みうる gh api のうち、展開・連結・閉じていない引用符を含むコマンドは確認する") if shell_special?(cmd)

  begin
    req = parse(cmd)
  rescue Unreadable, ArgumentError => e
    ask("gh api の形を読み取れなかった（#{e.message}）")
  end
  exit 0 if ["", "GET", "HEAD"].include?(req[:method])
  ask("gh api の #{req[:method]} は確認する") unless req[:method] == "PATCH"

  ask("PATCH の対象が issue・PR の本文かコメントではない（#{req[:endpoint]}）") unless req[:endpoint].match?(ALLOWED_ENDPOINT)
  ask("--input で渡す中身は確かめられない") if req[:input]
  ask("body 以外のフィールドを送っている（#{req[:fields].join(", ")}）") unless req[:fields] == ["body"]

  exit 0
rescue SystemExit
  raise
rescue
  # 判定に失敗したら通さずに確認へ倒す（以前の ask ルールと同じ側に失敗させる）
  ask("gh-api-patch-guard の判定に失敗した")
end
