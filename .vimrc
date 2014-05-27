set bg=dark
set tabstop=4 softtabstop=4 shiftwidth=4 noexpandtab
set autoindent 
set showmode
set showcmd
set ignorecase
set smartcase

execute pathogen#infect()
call pathogen#helptags()
let g:NERDTreeDirArrows=0
autocmd vimenter * if !argc() | NERDTree | endif
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif

syntax on
filetype plugin indent on

let g:ctags_statusline=1
nmap <F5> :!make<CR>
map <C-n> :NERDTreeToggle<CR>
