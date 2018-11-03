syntax on

if has ("autocmd")
    filetype plugin indent on
endif

call plug#begin('~/.vim/plugged')

Plug 'flazz/vim-colorschemes'

Plug 'PProvost/vim-ps1'

Plug 'Valloric/YouCompleteMe', { 'do': 'py .\install.py' }

call plug#end()

set background=dark

set autoindent

set shiftwidth=4 softtabstop=4

set number colorcolumn=80
set ruler showcmd

set hlsearch incsearch
set ignorecase smartcase

set wildmenu

set mouse=a

set backspace=indent,eol,start

nnoremap j gj
nnoremap k gk