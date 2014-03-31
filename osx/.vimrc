"-------------------------------------------------
" General

syntax enable
set t_Co=256
set background=dark
" colorscheme solarized
" let g:solarized_termcolors=256
" colorscheme desert
colorscheme molokai

set whichwrap=b,s,<,>,[,],~
set number

set autoindent
set smarttab
set expandtab
set tabstop=2
set shiftwidth=2
set backspace=2

set clipboard=unnamed,autoselect

set hlsearch
set incsearch
" set cursorline
" hi CursorLine term=reverse cterm=none ctermbg=233
set scrolloff=3
set visualbell t_vb=

nnoremap ; :

" disable emphasis on markdown
autocmd! FileType markdown hi! def link markdownItalic Normal

"-------------------------------------------------
" NeoBundle

if has('vim_starting')
  set nocompatible    " Be iMproved

  " Required:
  set runtimepath+=~/.vim/bundle/neobundle.vim/
endif

" Required:
call neobundle#rc(expand('~/.vim/bundle/'))

" Let NeoBundle manage NeoBundle
" Required:
NeoBundleFetch 'Shougo/neobundle.vim'

" My Bundles here:
NeoBundle 'Shougo/neosnippet.vim'
NeoBundle 'Shougo/neosnippet-snippets'
NeoBundle 'Shougo/unite.vim'
NeoBundle 'tsukkee/unite-help'
NeoBundle 'h1mesuke/unite-outline'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'gcmt/wildfire.vim'
" NeoBundle 'kien/ctrlp.vim'
NeoBundle 'flazz/vim-colorschemes'
NeoBundle 'Align'

" You can specify revision/branch/tag.
NeoBundle 'Shougo/vimshell', { 'rev' : '3787e5' }

" Required:
filetype plugin indent on

" If there are uninstalled bundles found on startup,
" this will conveniently prompt you to install them.
NeoBundleCheck

"-------------------------------------------------
" Neosnipet

" Plugin key-mappings.
imap <C-k>     <Plug>(neosnippet_expand_or_jump)
smap <C-k>     <Plug>(neosnippet_expand_or_jump)
xmap <C-k>     <Plug>(neosnippet_expand_target)

" SuperTab like snippets behavior.
imap <expr><TAB> neosnippet#expandable_or_jumpable() ?
\ "\<Plug>(neosnippet_expand_or_jump)"
\: pumvisible() ? "\<C-n>" : "\<TAB>"
smap <expr><TAB> neosnippet#expandable_or_jumpable() ?
\ "\<Plug>(neosnippet_expand_or_jump)"
\: "\<TAB>"

" For snippet_complete marker.
if has('conceal')
  set conceallevel=2 concealcursor=i
endif

"-------------------------------------------------
" wildfire.vim

let g:wildfire_objects = ["i'", 'i"', "i)", "i]", "i}", "ip", "it", "i>"]

"-------------------------------------------------
" Align

let g:Align_xstrlen = 3

