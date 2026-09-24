.PHONY: help install copy link install_packages doctor doctor-notify pull

help:
	@echo "make install          # copy and link files, then install packages"
	@echo "make copy             # copy config files"
	@echo "make link             # link dotfiles"
	@echo "make install_packages # install packages"
	@echo "make doctor           # check symlinks and hook runtimes/scripts"
	@echo "make doctor-notify    # send a test desktop notification"
	@echo "make pull             # git pull, preserving skip-worktree local diffs"

install: link install_packages

copy:
	@bash -c "cp -f ./.bashrc ~/.bashrc"
	@bash -c "[ -f /etc/paths ] && sudo cp -f ./etc/paths /etc/paths"

link:
	@bash ./scripts/link.sh

install_packages:
	@bash ./scripts/install_packages.sh

doctor:
	@test -x "$(HOME)/.local/share/mise/shims/ruby" || { echo "FAIL: mise の Ruby shim が見つからないか実行できません。mise のセットアップを確認してください。"; exit 1; }
	@"$(HOME)/.local/share/mise/shims/ruby" ./scripts/doctor.rb

doctor-notify:
	@"$(HOME)/.local/share/mise/shims/ruby" ./.claude/hooks/desktop-notify.rb --doctor

pull:
	@test -x "$(HOME)/.local/share/mise/shims/ruby" || { echo "FAIL: mise の Ruby shim が見つからないか実行できません。mise のセットアップを確認してください。"; exit 1; }
	@"$(HOME)/.local/share/mise/shims/ruby" ./scripts/pull.rb
