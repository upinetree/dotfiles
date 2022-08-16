# dotfiles

## Requirement

* Git
* Make

## Setup

```console
git clone https://github.com/upinetree/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && make install
```

Or run the scripts in `./etc/scripts` if your environment does not have a `make`.

## Change origin

After [GitHub SSH configuration](https://docs.github.com/ja/authentication/connecting-to-github-with-ssh):

```console
git remote set-url origin git@github.com:upinetree/dotfiles.git
```
