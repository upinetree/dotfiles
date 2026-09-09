---
name: squash
description: Squash branch commits into one with a why-centered commit message
---

# Squash

このブランチのコミットを1つにまとめ（squash）、コードから読み取れない why を中心にコミットメッセージを書いてください。

## 手順

1. `BASE` を特定する
   - 引数でベースブランチが指定された場合はそれを使う
   - それ以外は `git rev-parse --abbrev-ref @{upstream} 2>/dev/null || git rev-parse --abbrev-ref origin/HEAD` で取得する
2. `git log`, `git diff --stat`, `git diff` でブランチの変更全体を把握する
3. `git reset --soft $(git merge-base HEAD $BASE)` でコミットを soft reset する
4. 変更の全体像を踏まえ、Conventional Commits 形式のコミットメッセージを作成する
5. `git commit -m "..."` でコミットする

## コミットメッセージの方針

基本ルールはユーザー global CLAUDE.md「コミットメッセージ」に従う。判定基準は **その記述を消したとき diff から読み取れなくなる情報があるか**。

- 1行目: `<type>[scope]: <description>`（Conventional Commits）。ここは what でよい
- 本文: **コードから読み取れない why だけ**で構成する。squash 後は差分が大きいため、what を書き始めると diff の目録になる
  - なぜ必要だったか（問題・きっかけ）、なぜこの形にしたか（制約・採らなかった案）、diff に現れない前提・依存・波及、根拠（ADR・issue・PR）
  - why を主節に置く（「X を新設した。Y のためである」ではなく「Y のため X にした」）
  - 変更したクラス・メソッドの列挙、diff の言い換え、シンボル名の網羅列挙は書かない
  - `git diff --stat` の構造を見出しでミラーしない。分けるなら why の単位で分ける
  - 元コミットのメッセージを機械的に連結しない。実装途中の暫定表現や rebase で混入した `# Conflicts:` 行は捨て、最終状態の事実として書き直す
  - PR を既に作っている場合、PR 本文にしか無い why はコミット側へ移す（blame から辿れるのはコミット）
- フッター: Claude 由来のものとそれ以外で扱いを分ける
  - **Claude 由来の trailer**（`Claude-Session:`、`Co-Authored-By: Claude <...>`、`🤖 Generated with Claude Code` など）は元コミットから引き継がない。付与するかどうかは squash 後のコミット作成時に `~/.claude/settings.json` の `attribution` 設定（`commit` / `sessionUrl`）に従って決まるので、ここで手動コピーしたり `git commit -m` の本文に書き足したりしない
  - **それ以外の trailer**（人間による `Signed-off-by`、`Reviewed-by`、Issue 参照など）は `git log $BASE..HEAD` で元コミットを確認し、使われていれば引き継ぐ。複数あれば重複を除いてまとめる
  - 引き継ぐべき trailer が無ければ付与しない
