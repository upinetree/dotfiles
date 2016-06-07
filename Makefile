help:
	@echo "make install #=> link dotfiles"

install: link

link:
	bash ./etc/scripts/link.sh
