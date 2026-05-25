---
name: squash
description: Squash branch commits into one with a well-organized commit message
---

# Squash

このブランチのコミットを1つにまとめ（squash）、取り組んだ内容を整理したコミットメッセージを書いてください。

## 手順

1. `BASE` を特定する
   - 引数でベースブランチが指定された場合はそれを使う
   - それ以外は `git rev-parse --abbrev-ref @{upstream} 2>/dev/null || git rev-parse --abbrev-ref origin/HEAD` で取得する
2. `git log`, `git diff --stat`, `git diff` でブランチの変更全体を把握する
3. `git reset --soft $(git merge-base HEAD $BASE)` でコミットを soft reset する
4. 変更の全体像を踏まえ、Conventional Commits 形式のコミットメッセージを作成する
5. `git commit -m "..."` でコミットする

## コミットメッセージの方針

- 1行目: `<type>[scope]: <description>`（Conventional Commits）
- 本文: このブランチで取り組んだ内容を整理して記述する
  - 何を・なぜ変更したか（"what" と "why"）
  - 複数のトピックがあればセクションに分けて整理する
  - 設計上の判断や背景など、コードから読み取りにくい情報を含める
- フッター: `Co-Authored-By: Claude <noreply@anthropic.com>`
