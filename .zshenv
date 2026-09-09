# 非対話シェル（zsh -c / zsh -lc）でも mise 管理のツールを解決できるようにする。
# mise activate は .zshrc にあるが対話シェルでしか読まれず、サブエージェント等の
# シェルから codex 等が見えない問題への対策（.zshenv は全起動形態で読まれる）。
# 注意: login シェルでは後続の /etc/zprofile（path_helper）が shims をシステム
# パスの後ろに並べ替えるため、/usr/bin と競合する ruby/python は system 版が
# 勝つ。それらは呼び出し側で絶対パス参照する（hooks.json 方式）。
export PATH="$HOME/.local/share/mise/shims:$PATH"
