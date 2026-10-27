.PHONY: help install copy link install_packages doctor doctor-notify pull skills-list skills-check skills-update apps-list apps-check apps-update

help:
	@echo "make install          # copy and link files, then install packages"
	@echo "make copy             # copy config files"
	@echo "make link             # link dotfiles"
	@echo "make install_packages # install packages"
	@echo "make doctor           # check symlinks and hook runtimes/scripts"
	@echo "make doctor-notify    # send a test desktop notification"
	@echo "make pull             # git pull, preserving skip-worktree local diffs"
	@echo "make skills-list      # list vendored third-party skills and their pins"
	@echo "make skills-check     # flag vendored skills without a security-review record, or lagging their latest release"
	@echo "make skills-update NAME=<skill> REF=<tag>  # re-vendor a skill at <tag>; review it and record before committing"
	@echo "make apps-list        # list vendored macOS apps (mise macos-app) and installed versions"
	@echo "make apps-check       # flag vendored apps lagging their latest GitHub release"
	@echo "make apps-update NAME=<app> [REF=<tag>]  # pin an app to <tag> (default: latest) and install it"

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

skills-list:
	@"$(HOME)/.local/share/mise/shims/ruby" ./scripts/vendored_skills.rb list

skills-check:
	@"$(HOME)/.local/share/mise/shims/ruby" ./scripts/vendored_skills.rb check

skills-update:
	@test -n "$(NAME)" -a -n "$(REF)" || { echo "usage: make skills-update NAME=<skill> REF=<tag>"; exit 1; }
	@"$(HOME)/.local/share/mise/shims/ruby" ./scripts/vendored_skills.rb update "$(NAME)" "$(REF)"

apps-list:
	@"$(HOME)/.local/share/mise/shims/ruby" ./scripts/vendored_apps.rb list

apps-check:
	@"$(HOME)/.local/share/mise/shims/ruby" ./scripts/vendored_apps.rb check

apps-update:
	@test -n "$(NAME)" || { echo "usage: make apps-update NAME=<app> [REF=<tag>]"; exit 1; }
	@"$(HOME)/.local/share/mise/shims/ruby" ./scripts/vendored_apps.rb update "$(NAME)" $(REF)
