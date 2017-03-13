# Settings for the subshell when run `make install` from the dotfiles root

# local bin path
export PATH=/usr/local/bin:$PATH
export PATH=$HOME/bin:$PATH

# golang
export GOPATH=$HOME/.go
export PATH=$PATH:$GOPATH/bin
