---
allowed-tools: Bash(git log:*), Bash(git diff:*), Bash(git reset:*), Bash(git commit:*)
description: Squash branch commits into one with a well-organized commit message
---

## Context

- Current branch: !`git branch --show-current`
- Base ref (upstream if set, otherwise default branch): !`git rev-parse --abbrev-ref @{upstream} 2>/dev/null || git rev-parse --abbrev-ref origin/HEAD`
- Commits on this branch: !`git log @{upstream}..HEAD --oneline 2>/dev/null || git log origin/HEAD..HEAD --oneline`
- Diff stat from branch point: !`git diff @{upstream}...HEAD --stat 2>/dev/null || git diff origin/HEAD...HEAD --stat`
- Full diff from branch point: !`git diff @{upstream}...HEAD 2>/dev/null || git diff origin/HEAD...HEAD`

## Your task

このブランチのコミットを1つにまとめ（squash）、取り組んだ内容を整理したコミットメッセージを書いてください。

### 手順

1. `BASE` を特定する
   - 引数でベースブランチが指定された場合はそれを使う
   - それ以外は上記 Context の "Base ref" を使う
2. `git reset --soft $(git merge-base HEAD $BASE)` でコミットを soft reset する
3. 変更の全体像を把握した上で、Conventional Commits 形式のコミットメッセージを作成する
4. `git commit -m "..."` でコミットする

### コミットメッセージの方針

- 1行目: `<type>[scope]: <description>`（Conventional Commits）
- 本文: このブランチで取り組んだ内容を整理して記述する
  - 何を・なぜ変更したか（"what" と "why"）
  - 複数のトピックがあればセクションに分けて整理する
  - 設計上の判断や背景など、コードから読み取りにくい情報を含める
- フッター: `Co-Authored-By: Claude <noreply@anthropic.com>`
