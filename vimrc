" Set standard file encoding
set encoding=utf8

" No special per file vim override configs
set nomodeline

" Stop word wrapping
set nowrap

" Except... on Markdown. Thats good stuff.
autocmd FileType markdown setlocal wrap

" Adjust system undo levels
set undolevels=100

" Use system clipboard
set clipboard=unnamed

" Set tab width and convert tabs to spaces
set tabstop=2
set softtabstop=2
set shiftwidth=2
set expandtab

" Dont let Vim hide characters or make loud dings
set conceallevel=1
set noerrorbells

" Number gutter
set number

" Use search highlighting
set hlsearch

" Space above/beside cursor from screen edges
set scrolloff=1
set sidescrolloff=5

" Bind map leader to space
let mapleader="\<SPACE>

" Disable mouse support
set mouse=r
let $NVIM_TUI_ENABLE_CURSOR_SHAPE=1

nnoremap <Left> :vertical resize -1<CR>
nnoremap <Right> :vertical resize +1<CR>
nnoremap <Up> :resize -1<CR>
nnoremap <Down> :resize +1<CR>
" Disable arrow keys completely in Insert Mode
imap <up> <nop>
imap <down> <nop>
imap <left> <nop>
imap <right> <nop>

" Return to last file opened
nmap <Leader><Leader> <c-^>

" Next and Previous buffers
nnoremap <Tab> :bnext!<CR>
nnoremap <S-Tab> :bprev!<CR><Paste>

" Plugins
call plug#begin('~/.local/share/nvim/plugged')
Plug 'Shougo/unite.vim'
Plug 'dracula/vim'
color Dracula

Plug 'Yggdroot/indentLine'
let g:indentLine_enabled = 1
let g:indentLine_char = "⟩"

Plug 'airblade/vim-gitgutter'

Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
let g:airline#extensions#tabline#enabled=1let g:airline_powerline_fonts=1
set laststatus=2

Plug 'ctrlpvim/ctrlp.vim', { 'on': 'CtrlP' }
nnoremap <Leader>p :CtrlP<CR>
nnoremap <Leader>t :CtrlP<CR>
call plug#end()

