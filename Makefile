help:
	@echo "make install          # copy and link files, then install packages"
	@echo "make copy             # copy config files"
	@echo "make link             # link dotfiles"
	@echo "make clone_extra      # clone extra preferred repos"
	@echo "make vimperator       # setup vimperator plugins"
	@echo "make install_packages # install packages"

install: copy link install_packages

copy:
	@bash -c "[ -f /etc/paths ] && sudo cp -f ./etc/paths /etc/paths"

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
