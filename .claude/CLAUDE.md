# ユーザーローカル CLAUDE.md（全プロジェクト共通）

このファイルは `~/.dotfiles/.claude/CLAUDE.md` が実体で、`~/.claude/CLAUDE.md` から symlink される。編集はこの dotfiles 側で行う（`hooks/` と同じ運用）。

## `~/.claude` 環境の構成と落とし穴

dotfiles（toplevel `~/.dotfiles`、`master` ブランチ）で管理している。`.claude` 配下の同期方式が項目ごとに違うので注意:

- **`hooks/` は symlink**: `~/.claude/hooks → ~/.dotfiles/.claude/hooks`。1か所を編集すれば live にも追跡対象にも反映される。
- **`settings.json` は symlink ではなく独立した2ファイル**:
  - `~/.claude/settings.json` … Claude Code が実際に読む live ファイル
  - `~/.dotfiles/.claude/settings.json` … dotfiles の追跡ファイル
  - **片方だけ編集すると設定が食い違う。両方を同一内容に更新すること。** 変更後は `diff` で一致を確認する。
- コミットは `~/.dotfiles` で行う（`git -C ~/.dotfiles ...`）。

## 自作スクリプトの言語方針

- `~/.claude` 配下の自作スクリプト（hooks / skills のヘルパー）は **Ruby に統一**する。新規も Ruby で書き、Python は使わない。
- Obsidian 連携など外部 CLI を叩くスクリプトの設計知見はプロジェクトメモリ（`reference_obsidian_cli_vault` 等）を参照。
