.PHONY: help install copy link install_packages

help:
	@echo "make install          # copy and link files, then install packages"
	@echo "make copy             # copy config files"
	@echo "make link             # link dotfiles"
	@echo "make install_packages # install packages"

install: link install_packages

copy:
	@bash -c "cp -f ./.bashrc ~/.bashrc"
	@bash -c "[ -f /etc/paths ] && sudo cp -f ./etc/paths /etc/paths"

link:
	@bash ./scripts/link.sh

install_packages:
	@bash ./scripts/install_packages.sh

