syntax enable
set background=dark
colorscheme solarized
" colorscheme molokai 
" set t_Co=256

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

nnoremap ; :

set visualbell t_vb=

" disable emphasis on markdown
autocmd! FileType markdown hi! def link markdownItalic Normal
