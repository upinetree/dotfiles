help:
	@echo "make install   			 # link dotfiles and install packages"
	@echo "make install_packages # install packages"
	@echo "make link     				 # link dotfiles"

install: link install_packages

link:
	@bash ./etc/scripts/link.sh

install_packages:
	@bash ./etc/scripts/install_packages.sh
