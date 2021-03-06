syntax on

if has ("autocmd")
    filetype plugin indent on
endif

call plug#begin('~/.vim/plugged')

Plug 'flazz/vim-colorschemes'

Plug 'PProvost/vim-ps1'

Plug 'Valloric/YouCompleteMe', { 'do': 'python3 ./install.py --clang-completer --rust-completer --java-completer' }

Plug 'vim-erlang/vim-erlang-omnicomplete'
Plug 'vim-erlang/vim-erlang-compiler'
Plug 'vim-erlang/vim-erlang-runtime'
Plug 'vim-erlang/vim-erlang-tags'
Plug 'vim-erlang/vim-rebar'
Plug 'vim-erlang/vim-dialyzer'

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

colo luna-term