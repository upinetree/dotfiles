"-------------------------------------------------
" General

syntax enable
set t_Co=256
set background=dark
" colorscheme molokai
" colorscheme hybrid
colorscheme lucius

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

" 括弧やクオートの自動補完
inoremap {<Enter> {}<Left><CR><ESC><S-o>
inoremap [<Enter> []<Left><CR><ESC><S-o>
inoremap (<Enter> ()<Left><CR><ESC><S-o>
inoremap { {}<LEFT>
inoremap [ []<LEFT>
inoremap ( ()<LEFT>
inoremap " ""<LEFT>
inoremap ' ''<LEFT>
vnoremap { "zdi{<C-R>z}<ESC>
vnoremap [ "zdi[<C-R>z]<ESC>
vnoremap ( "zdi(<C-R>z)<ESC>
vnoremap " "zdi"<C-R>z"<ESC>
vnoremap ' "zdi'<C-R>z'<ESC>

" %キーでカッコとかdo-endとかに飛ぶ
if !exists('loaded_matchit')
  runtime macros/matchit.vim
endif

" 全角記号文字の幅を設定
set ambiwidth=double

" spaces & tabs highlighting
highlight WhitespaceEOL term=underline ctermbg=red guibg=red
au BufWinEnter * let w:m1 = matchadd("WhitespaceEOL", '\s\+$')
au WinEnter * let w:m1 = matchadd("WhitespaceEOL", '\s\+$')

highlight TabString ctermbg=red guibg=red
au BufWinEnter * let w:m2 = matchadd("TabString", '^\t+')
au WinEnter * let w:m2 = matchadd("TabString", '^\t+')

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
NeoBundle 'Shougo/neomru.vim'
NeoBundle 'tsukkee/unite-help'
NeoBundle 'h1mesuke/unite-outline'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'gcmt/wildfire.vim'
" NeoBundle 'kien/ctrlp.vim'
NeoBundle 'flazz/vim-colorschemes'
NeoBundle 'Align'
NeoBundle "tyru/caw.vim"

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

"-------------------------------------------------
" Unite

let g:unite_enable_start_insert=1

nnoremap [unite]  <Nop>
nmap     <Space>u [unite]

nnoremap <silent> [unite]m :<C-u>Unite file_mru<CR>
nnoremap <silent> [unite]b :<C-u>Unite buffer<CR>
nnoremap <silent> [unite]a :<C-u>Unite file_rec -buffer-name=files file<CR>
nnoremap <silent> [unite]y :<C-u>Unite -buffer-name=register register<CR>

"-------------------------------------------------
" Caw

nmap <Space>c <Plug>(caw:i:toggle)
vmap <Space>c <Plug>(caw:i:toggle)
