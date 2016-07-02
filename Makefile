help:
	@echo "make install  # setup and link"
	@echo "make setup    # setup commands"
	@echo "make link     # link dotfiles"

install: setup link

setup:
	@bash ./etc/scripts/setup.sh

link:
	@bash ./etc/scripts/link.sh
