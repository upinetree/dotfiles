help:
	@echo "make install          # link dotfiles and install packages"
	@echo "make install_packages # install packages"
	@echo "make link             # link dotfiles"
	@echo "make clone_extra      # clone extra preferred repos"
	@echo "make vimperator       # setup vimperator plugins"

install: link install_packages

link:
	@bash ./scripts/link.sh

install_packages:
	@bash ./scripts/install_packages.sh

clone_extra:
	ghq get vimpr/vimperator-plugins
	ghq get mbadolato/iTerm2-Color-Schemes

vimperator:
	[ -d ~/.vimperator/plugin ] || mkdir ~/.vimperator/plugin
	$(eval src_root := $(shell ghq list -p vimpr/vimperator-plugins))
	-ln -s "$(src_root)/_libly.js" ~/.vimperator/plugin/_libly.js
	-ln -s "$(src_root)/_smooziee.js" ~/.vimperator/plugin/_smooziee.js
	-ln -s "$(src_root)/copy.js" ~/.vimperator/plugin/copy.js
