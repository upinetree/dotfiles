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

## Bash コマンド実行の作法

permission classifier はコマンドの複合度と依頼文脈との乖離に反応して拒否する。

- 1コマンド1目的で分割する。書き込み系を `&&` やパイプで連結しない。`cd A && B` は `make -C` / `git -C` で代替する
- `rm` は拒否される前提で組む。untracked ファイルは `git clean -f <path>`、それ以外は /tmp へ mv か別名作成で回避する
- 権限拒否されたら同じ形でリトライしない。どこまで実行されたかを確認し、分割・依頼文脈の明示・ユーザーによる実行（`!`）や allowlist 追加の案内に切り替える。allowlist 拡張の提案は曖昧な範囲でなく具体的なコマンドの列挙で行う

## 検証の証拠主義

- 完了報告（自分・サブエージェントとも）は成果物の実在（コミット・ファイル・API 応答・transcript の tool_use）で検証してから伝える。サブエージェントの返答テキストだけを根拠にしない
- lint・構文チェック・通常テストの green は failure-only（失敗時のみ走る）コードの検証にならない。レアパスは一度実発火させて実ログで確認する
- 仮説は突き合わせ可能な実データ（時刻・ID・実測値）で確定させる。症状の一致だけで同根と断定しない
