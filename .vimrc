if $COLORTERM == 'gnome-terminal'
  set t_Co=256
endif

set t_Co=256

" Numbers in gutter
set number

" Spell checking
set spell

" Specify a directory for plugins
call plug#begin('~/.vim/plugged')

" delimitmate
Plug 'raimondi/delimitmate'

" NERD tree will be loaded on the first invocation of NERDTreeToggle command
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
Plug 'jistr/vim-nerdtree-tabs'

" NERD Commenter
Plug 'scrooloose/nerdcommenter'

" Fugitive for Git
Plug 'tpope/vim-fugitive'

" Airline
Plug 'bling/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'bling/vim-bufferline'

" Gitgutter
Plug 'airblade/vim-gitgutter'

" Indent Guides
Plug 'nathanaelkane/vim-indent-guides'

" Syntastic
" Plug 'scrooloose/syntastic'

" Misc Bundle
Plug 'xolox/vim-misc'

" Easy Tags
"Plug 'xolox/vim-easytags'

"Plug 'christoomey/vim-tmux-navigator'
Plug 'christoomey/vim-tmux-navigator'


" CtrlP
Plug 'ctrlpvim/ctrlp.vim'
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'

" Neocomplete
" Plug 'shougo/neocomplete.vim'

" Color scheme
Plug 'flazz/vim-colorschemes'

" Py mode
Plug 'klen/python-mode'

" Jedi
Plug 'davidhalter/jedi-vim'

" ALE
Plug 'w0rp/ale'

" Initialize plugin system
call plug#end()

" ColorScheme
colorscheme molokai
let g:airline_theme='molokai'

" Make the gutters darker than the background.
let g:badwolf_darkgutter = 1

" Fix the slight delay
set ttimeoutlen=10
" Fixing airline
let g:airline_powerline_fonts = 1
if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif

let g:airline_symbols.space = "\ua0"

set laststatus=2

let g:airline_skip_empty_sections = 1

" Turn on NERDTree
map <C-n> :NERDTreeToggle<CR>

" ALE & airline
function! LinterStatus() abort
    let l:counts = ale#statusline#Count(bufnr(''))

    let l:all_errors = l:counts.error + l:counts.style_error
    let l:all_non_errors = l:counts.total - l:all_errors

    return l:counts.total == 0 ? 'OK' : printf(
    \   '%dW %dE',
    \   all_non_errors,
    \   all_errors
    \)
endfunction

set statusline=%{LinterStatus()}
