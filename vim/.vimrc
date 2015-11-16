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

inoremap <C-L> <ESC>
vnoremap <C-L> <ESC>
nnoremap ; :

nnoremap <Space>w :<C-u>w<CR>
nnoremap <Space>q :<C-u>q<CR>
nnoremap <Space>Q :<C-u>bd<CR>
nnoremap <Space>n :<C-u>noh<CR>
nnoremap <Space>t :<C-u>tabnew<CR>
nnoremap <Space>h <C-w>h
nnoremap <Space>j <C-w>j
nnoremap <Space>k <C-w>k
nnoremap <Space>l <C-w>l
nnoremap <C-n> gt
nnoremap <C-p> gT

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

" disable emphasis on markdown
autocmd! FileType markdown hi! def link markdownItalic Normal

" 自動的にquickfix-windowを開く（位置調整済み）
autocmd! QuickFixCmdPost *grep* belowright cwindow


"-------------------------------------------------
" NeoBundle

if has('vim_starting')
  if &compatible
    set nocompatible  " Be iMproved
  endif

  " Required:
  set runtimepath+=~/.vim/bundle/neobundle.vim/
endif

" Required:
call neobundle#begin(expand('~/.vim/bundle/'))

" Let NeoBundle manage NeoBundle
" Required:
NeoBundleFetch 'Shougo/neobundle.vim'

" My Bundles here:
NeoBundle "tpope/vim-haml"
NeoBundle "tyru/caw.vim"
NeoBundle 'Align'
NeoBundle 'AndrewRadev/vim-eco'
NeoBundle 'Shougo/neomru.vim'
NeoBundle 'Shougo/neosnippet-snippets'
NeoBundle 'Shougo/neosnippet.vim'
NeoBundle 'Shougo/unite.vim'
NeoBundle 'Shougo/vimshell'
NeoBundle 'flazz/vim-colorschemes'
NeoBundle 'gcmt/wildfire.vim'
NeoBundle 'h1mesuke/unite-outline'
NeoBundle 'kchmck/vim-coffee-script'
NeoBundle 'nathanaelkane/vim-indent-guides'
NeoBundle 'ntpeters/vim-better-whitespace'
NeoBundle 's3rvac/vim-syntax-redminewiki'
NeoBundle 'slim-template/vim-slim'
NeoBundle 'timcharper/textile.vim'
NeoBundle 'tpope/vim-endwise'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'tsukkee/unite-help'

NeoBundle 'Shougo/vimproc.vim', {
    \ 'build' : {
    \     'windows' : 'tools\\update-dll-mingw',
    \     'cygwin' : 'make -f make_cygwin.mak',
    \     'mac' : 'make -f make_mac.mak',
    \     'unix' : 'make -f make_unix.mak',
    \    },
    \ }

call neobundle#end()

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

nnoremap <silent> [unite]u :<C-u>Unite buffer file_mru<CR>
nnoremap <silent> [unite]g :<C-u>Unite file_rec/git<CR>
nnoremap <silent> [unite]a :<C-u>Unite file_rec/async<CR>
nnoremap <silent> [unite]y :<C-u>Unite -buffer-name=register register<CR>

"-------------------------------------------------
" Caw

nmap <Space>c <Plug>(caw:i:toggle)
vmap <Space>c <Plug>(caw:i:toggle)


"-------------------------------------------------
" IndentGuides

let g:indent_guides_enable_on_vim_startup=1
let g:indent_guides_guide_size=1
let g:indent_guides_start_level = 3
let indent_guides_color_change_percent = 5
let indent_guides_auto_colors = 0
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg=darkgrey ctermbg=236
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven guibg=darkgrey ctermbg=237
