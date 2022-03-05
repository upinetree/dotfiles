" Remove existing autocommands for when the file is sourced twice
autocmd!


"
" Dein.vim
"
if &compatible
  set nocompatible
endif
set runtimepath+=~/.cache/dein-nvim/repos/github.com/Shougo/dein.vim

call dein#begin('~/.cache/dein-nvim')

" Let dein manage dein
call dein#add('~/.cache/dein-nvim/repos/github.com/Shougo/dein.vim')

call dein#add('Shougo/deol.nvim')
call dein#add('Shougo/vimproc.vim', {'build' : 'make'})
call dein#add('cohama/lexima.vim')
call dein#add('ctrlpvim/ctrlp.vim')
call dein#add('fatih/vim-go')
call dein#add('flazz/vim-colorschemes')
call dein#add('itchyny/lightline.vim')
call dein#add('ivalkeen/vim-ctrlp-tjump')
call dein#add('mattn/ctrlp-matchfuzzy')
call dein#add('nathanaelkane/vim-indent-guides')
call dein#add('ntpeters/vim-better-whitespace')
call dein#add('tpope/vim-fugitive')
call dein#add('tpope/vim-obsession')
call dein#add('tpope/vim-rhubarb')
call dein#add('tpope/vim-surround')
call dein#add('tyru/caw.vim')
call dein#add('vim-scripts/Align')

call dein#end()


"
" Configuration
" https://neovim.io/doc/user/vim_diff.html
"
filetype plugin indent on

set ambiwidth=double " 全角記号文字の幅を設定
set breakindent
set breakindentopt=sbr
set clipboard=unnamedplus
set expandtab
set scrolloff=3
set shiftround
set shiftwidth=2
set showbreak=>\ 
set tabstop=2
set whichwrap=b,s,<,>,[,],~

" Display options
set background=dark
set number
colorscheme lucius
set noshowmode " for itchyny/lightline.vim

" Performance improvements
set lazyredraw
set synmaxcol=300

" Open grep results in the quickfix-window
autocmd QuickFixCmdPost *grep* belowright cwindow


"
" FileType settings
"
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
endfunction

autocmd FileType go call s:go_filetype_settings()
function! s:go_filetype_settings()
  setlocal tabstop=4 shiftwidth=4 softtabstop=4 noet
  setlocal completeopt-=preview
endfunction

" disable emphasis on markdown
autocmd FileType markdown hi! def link markdownItalic Normal

"
" Plugin options
"

" Align
let g:Align_xstrlen = 3

" IndentGuides
let g:indent_guides_enable_on_vim_startup=1
let g:indent_guides_guide_size=1
let g:indent_guides_start_level = 3
let indent_guides_color_change_percent = 5
let indent_guides_auto_colors = 0
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg=darkgrey ctermbg=236
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven guibg=darkgrey ctermbg=237

" Lightline
" ref https://github.com/statico/dotfiles/blob/39a64bbbe037793a2d77298311f7f90fcf0b8da5/.vim/vimrc#L371
let g:lightline = {
\ 'colorscheme': 'darcula',
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

" CtrlP
let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files -co --exclude-standard']
let g:ctrlp_match_func = {'match': 'ctrlp_matchfuzzy#matcher'}

"
" Key Mappings
"
nnoremap <Space>n :<C-u>noh<CR>

" Edit
inoremap <C-L> <ESC>
inoremap <silent> jj <ESC>
inoremap <silent> っｊ <ESC>
vnoremap <C-L> <ESC>

" IME
nnoremap あ a
nnoremap い i
nnoremap う u
nnoremap お o

" VSCode Neovim exclusion
if !exists('g:vscode')
  " File, Window, Tab
  nnoremap QQ :<C-u>q!<CR>
  nnoremap <Space>q :<C-u>q<CR>
  nnoremap <Space>Q :<C-u>bd<CR>
  nnoremap <Space>w :<C-u>w<CR>
  nnoremap <Space>t :<C-u>tabnew<CR>
  nnoremap <Space>h <C-w>h
  nnoremap <Space>j <C-w>j
  nnoremap <Space>k <C-w>k
  nnoremap <Space>l <C-w>l
  nnoremap <Space>e :<C-u>Explore<CR>
  nnoremap <Space>s :<C-u>Sexplore<CR>
  nnoremap <Tab> gt
  nnoremap <S-Tab> gT
  nnoremap <silent> <Space>m :<C-u>call <SID>MoveToNewTab()<CR>

  " ctrlp
  nnoremap <c-]> :CtrlPtjump<cr>
  vnoremap <c-]> :CtrlPtjumpVisual<cr>
end

" surround.vim
vmap { S{
vmap [ S[
vmap ( S(
vmap " S"
vmap ' S'
vmap ` S`

" Caw
nmap <Space>c <Plug>(caw:hatpos:toggle)
vmap <Space>c <Plug>(caw:hatpos:toggle)

"
" Functions
"
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

