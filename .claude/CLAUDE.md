# ユーザーローカル CLAUDE.md（全プロジェクト共通）

実体は `~/.dotfiles/.claude/CLAUDE.md`、`~/.claude/CLAUDE.md` から symlink される。編集はこの dotfiles 側で行う。

## Claude の設定・hooks・skills を変更するとき

`~/.claude` 配下の設定は dotfiles からの symlink である（`~/.dotfiles/scripts/link.sh` の `DOTFILE_PAIRS`、`make link` で適用）。

- `~/.claude/settings.json` → `~/.dotfiles/.claude/settings.json`
- `~/.claude/hooks` → `~/.dotfiles/.claude/hooks`
- `~/.claude/skills/<name>` → `~/.dotfiles/.claude/skills/<name>`（ディレクトリ単位で自動 link）
- `~/.claude/CLAUDE.md` → `~/.dotfiles/.claude/CLAUDE.md`

変更は **dotfiles 側の実体を編集**し、`~/.dotfiles` でコミットする。`~/.claude` 側を直接編集しない。

対象が symlink ではなく実ファイルになっていたら symlink が壊れている（Claude Code が設定を直接書き換えると起きうる）。`make link`（または該当 1 本を貼り直し）で復旧してから編集し、内容が分岐した 2 コピーを残さない。
