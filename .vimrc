" Remove existing autocommands for when the file is sourced twice
autocmd!

"-------------------------------------------------
" Dein.vim

if &compatible
  set nocompatible
endif
set runtimepath^=~/.vim/bundle/repos/github.com/Shougo/dein.vim

if dein#load_state('~/.vim/bundle')
  call dein#begin(expand('~/.vim/bundle'))

  call dein#add('Shougo/dein.vim')

  call dein#add('AndrewRadev/vim-eco')
  call dein#add('Shougo/neomru.vim')
  call dein#add('Shougo/neosnippet-snippets')
  call dein#add('Shougo/neosnippet.vim')
  call dein#add('Shougo/unite-help')
  call dein#add('Shougo/unite-outline')
  call dein#add('Shougo/unite.vim')
  call dein#add('Shougo/vimproc.vim', {'build' : 'make'})
  call dein#add('Shougo/vimshell')
  call dein#add('cohama/lexima.vim')
  call dein#add('fatih/vim-go')
  call dein#add('flazz/vim-colorschemes')
  call dein#add('itchyny/lightline.vim')
  call dein#add('kchmck/vim-coffee-script')
  call dein#add('maxmellon/vim-jsx-pretty')
  call dein#add('nathanaelkane/vim-indent-guides')
  call dein#add('ntpeters/vim-better-whitespace')
  call dein#add('pangloss/vim-javascript')
  call dein#add('s3rvac/vim-syntax-redminewiki')
  call dein#add('slim-template/vim-slim')
  call dein#add('thinca/vim-qfreplace')
  call dein#add('timcharper/textile.vim')
  call dein#add('tpope/vim-fugitive')
  call dein#add('tpope/vim-haml')
  call dein#add('tpope/vim-rhubarb')
  call dein#add('tpope/vim-surround')
  call dein#add('tyru/caw.vim')
  call dein#add('vim-scripts/Align')
  call dein#add('w0rp/ale')

  call dein#end()
  call dein#save_state()
endif

filetype plugin indent on

" If you want to install not installed plugins on startup.
"if dein#check_install()
"  call dein#install()
"endif

"-------------------------------------------------
" Key Mappings

" Prefix
nnoremap [unite]  <Nop>
nmap     <Space>u [unite]

" Edit
inoremap <C-L> <ESC>
vnoremap <C-L> <ESC>

" File, Window, Tab
nnoremap <Space>w :<C-u>w<CR>
nnoremap <Space>q :<C-u>q<CR>
nnoremap <Space>Q :<C-u>bd<CR>
nnoremap <Space>n :<C-u>noh<CR>
nnoremap <Space>t :<C-u>tabnew<CR>
nnoremap <Space>e :<C-u>Explore<CR>
nnoremap <Space>s :<C-u>Sexplore<CR>
nnoremap <Space>h <C-w>h
nnoremap <Space>j <C-w>j
nnoremap <Space>k <C-w>k
nnoremap <Space>l <C-w>l
nnoremap <C-n> gt
nnoremap <C-p> gT
nnoremap <silent> <Space>m :<C-u>call <SID>MoveToNewTab()<CR>
function! s:MoveToNewTab()
  tab split
  tabprevious

  if winnr('$') > 1
      close
  elseif bufnr('$') > 1
      buffer #
  endif

  tabnext
endfunction

" surround.vim shortcuts
vmap { S{
vmap [ S[
vmap ( S(
vmap " S"
vmap ' S'
vmap ` S`

" Unite
nnoremap <silent> [unite]u :<C-u>Unite buffer file_mru<CR>
nnoremap <silent> [unite]g :<C-u>Unite file_rec/git:--cached:--others:--exclude-standard<CR>
nnoremap <silent> [unite]a :<C-u>Unite file_rec/async<CR>
nnoremap <silent> [unite]y :<C-u>Unite -buffer-name=register register<CR>
nnoremap <silent> [unite]o :<C-u>Unite outline<CR>
nnoremap <silent> [unite]h :<C-u>Unite help<CR>

" Caw
nmap <Space>c <Plug>(caw:hatpos:toggle)
vmap <Space>c <Plug>(caw:hatpos:toggle)

"-------------------------------------------------
" Rendering Options

syntax enable
set t_Co=256
set background=dark
" colorscheme molokai
" colorscheme hybrid
colorscheme lucius

set ambiwidth=double " 全角記号文字の幅を設定
set breakindent
set breakindentopt=sbr
set showbreak=>\ 
set hlsearch
set incsearch
set laststatus=2
set noshowmode
set number
set scrolloff=3

" Performance improvements
set lazyredraw
set synmaxcol=300

"-------------------------------------------------
" General Options

" System
set belloff=all
set clipboard=unnamed,autoselect

" Editor
set autoindent
set smarttab
set expandtab
set tabstop=2
set shiftwidth=2
set shiftround
set backspace=2
set whichwrap=b,s,<,>,[,],~

" Open Vim internal help by K command
set keywordprg=:Ggrep

" %キーでカッコとかdo-endとかに飛ぶ
if !exists('loaded_matchit')
  runtime macros/matchit.vim
endif

" Open grep results in the quickfix-window
autocmd QuickFixCmdPost *grep* belowright cwindow

"-------------------------------------------------
" FileType settings

autocmd FileType vim call s:vim_filetype_settings()
function! s:vim_filetype_settings()
  setlocal completeopt-=preview
  setlocal keywordprg=:help
endfunction

autocmd FileType help call s:help_filetype_settings()
function! s:help_filetype_settings()
  setlocal keywordprg=:help
endfunction

autocmd FileType ruby call s:ruby_filetype_settings()
function! s:ruby_filetype_settings()
  setlocal tabstop=2 shiftround shiftwidth=2
  setlocal completeopt-=preview
  setlocal keywordprg=:Ggrep
endfunction

" disable emphasis on markdown
autocmd FileType markdown hi! def link markdownItalic Normal

"-------------------------------------------------
" Neosnipet

" Plugin key-mappings.
imap <C-k> <Plug>(neosnippet_expand_or_jump)
smap <C-k> <Plug>(neosnippet_expand_or_jump)
xmap <C-k> <Plug>(neosnippet_expand_target)

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
" Align

let g:Align_xstrlen = 3

"-------------------------------------------------
" Unite

let g:unite_enable_start_insert=1

call unite#custom#source('buffer,file_rec/git', 'matchers', 'matcher_fuzzy')
call unite#custom#source('buffer,file_rec/git', 'converters', 'converter_relative_abbr')
call unite#custom#source('buffer,file_rec/git', 'sorters', 'sorter_selecta') " may slower
call unite#custom#source('buffer,file_rec/git', 'ignore_pattern', '\(png\|gif\|jpeg\|jpg\)$')

"-------------------------------------------------
" IndentGuides

let g:indent_guides_enable_on_vim_startup=1
let g:indent_guides_guide_size=1
let g:indent_guides_start_level = 3
let indent_guides_color_change_percent = 5
let indent_guides_auto_colors = 0
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg=darkgrey ctermbg=236
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven guibg=darkgrey ctermbg=237

"-------------------------------------------------
" Ale
" let g:ale_statusline_format = ['⨉ %d', '⚠ %d', '⬥ ok']
let g:ale_sign_warning = '⚠'
let g:ale_sign_error = '✗'
let g:ale_echo_msg_format = '[%linter%] %s [%severity%/%code%]'
let g:ale_lint_delay = 3000

let g:ale_fixers = {
\   'javascript': ['prettier', 'eslint'],
\}
" let g:ale_fix_on_save = 1

highlight link ALEWarningSign String
highlight link ALEErrorSign Title

"-------------------------------------------------
" Lightline
" https://github.com/statico/dotfiles/blob/master/.vim/vimrc#L415
let g:lightline = {
\ 'active': {
\   'left': [
\     ['mode', 'paste'],
\     ['readonly', 'filename', 'modified'],
\     ['linter_warnings', 'linter_errors', 'linter_ok'],
\   ]
\ },
\ 'inactive': {
\   'left': [
\     ['relativepath', 'modified']
\   ]
\ },
\ 'component_expand': {
\   'linter_warnings': 'LightlineLinterWarnings',
\   'linter_errors': 'LightlineLinterErrors',
\   'linter_ok': 'LightlineLinterOK'
\ },
\ 'component_type': {
\   'linter_warnings': 'warning',
\   'linter_errors': 'error'
\ }
\ }

function! LightlineLinterWarnings() abort
  let l:counts = ale#statusline#Count(bufnr(''))
  let l:all_errors = l:counts.error + l:counts.style_error
  let l:all_non_errors = l:counts.total - l:all_errors
  return l:counts.total == 0 ? '' : printf('%d ⚠', all_non_errors)
endfunction

function! LightlineLinterErrors() abort
  let l:counts = ale#statusline#Count(bufnr(''))
  let l:all_errors = l:counts.error + l:counts.style_error
  let l:all_non_errors = l:counts.total - l:all_errors
  return l:counts.total == 0 ? '' : printf('%d ✗', all_errors)
endfunction

function! LightlineLinterOK() abort
  let l:counts = ale#statusline#Count(bufnr(''))
  let l:all_errors = l:counts.error + l:counts.style_error
  let l:all_non_errors = l:counts.total - l:all_errors
  return l:counts.total == 0 ? '✓ ' : ''
endfunction

autocmd User ALELint call lightline#update()
