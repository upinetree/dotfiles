# WSL から Windows の Obsidian を使う

この文書は WSL で Obsidian 接続に失敗した場合だけ読む。

1. Windows 側で CLI 対応の Obsidian インストーラー（1.12.7 以降）へ更新し、Settings → General → Command line interface を有効にする。アプリ内更新だけで CLI が追加されない場合はインストーラーを更新する。[公式 CLI ドキュメント](https://help.obsidian.md/cli)
2. Windows 側で使いたい vault を開く。
3. WSL の通常のターミナルで `ruby <skill-dir>/scripts/obsidian.rb check` を実行する。

ヘルパーは PATH の `obsidian` を優先する。WSL では続いて PATH の `Obsidian.com` と Windows の標準的な設置先を調べる。`Obsidian.exe` は GUI 用なので CLI の代わりに使わない。複数候補や標準外の設置先では、`OBSIDIAN_CLI` に WSL から見える実行ファイルの絶対パスを指定する（引数を含めない）:

```bash
OBSIDIAN_CLI='/mnt/c/Users/USER/AppData/Local/Obsidian/Obsidian.com' ruby <skill-dir>/scripts/obsidian.rb check
```

以降のタグ取得・保存にも同じ環境変数を渡す。複数 vault がある場合は `OBSIDIAN_VAULT` も固定する。Windows パスはヘルパーが `wslpath -u` で変換するため、WSL から vault の実ファイルを読み書きできる必要がある。

- `UNAVAILABLE`（終了コード 2）: CLI が見つからない。設置先と CLI 登録を確認するか、スキルのローカル保存手順を使う。
- `FAIL`（終了コード 1）: 実行失敗、CLI の無効化、vault の解決・アクセス失敗など。表示された原因を解消して再実行する。別の保存先には自動で切り替えない。
- 通常の WSL ターミナルでは成功し、エージェントからのみ失敗する場合: sandbox の Windows interop 制限を切り分ける。アプリの再インストールで解決すると決めつけない。

診断・保存ヘルパーはアプリやモジュールを自動インストールせず、Windows の設定も変更しない。
