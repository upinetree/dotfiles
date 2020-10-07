" Remove existing autocommands for when the file is sourced twice
autocmd!

"
" Configuration
" https://neovim.io/doc/user/vim_diff.html
"
set ambiwidth=double " 全角記号文字の幅を設定
set clipboard=unnamedplus
set expandtab
set number
set scrolloff=3
set shiftwidth=2
set showbreak=>\ 
set tabstop=2

"
" Key Mappings
"
nnoremap <Space>n :<C-u>noh<CR>

if !exists('g:vscode')
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
end

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
