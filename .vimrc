set nocompatible " Use Vim settings instead of Vi Must be first

" General Config
set t_Co=256               " Set Colors to 256
set mouse=a                " Mouse use
set history=1000           " Reduce Vim's short term memory loss
set number                 " Numbers in gutter
set spell                  " Spell checking
set hidden                 " Allows current buffer to be moved to background without writing to disk
syntax enable              " Turns on Syntax
runtime macros/matchit.vim " Allows % to switch between if/else/etc.
set wildmenu=list:longest  " <TAB> in command shows completion
let mapleader = "<SPACE>"  " Sets leader to <Space>
" Specify a directory for plugins
call plug#begin('~/.vim/plugged')

Plug 'bling/vim-airline'                               " Airline
Plug 'vim-airline/vim-airline-themes'                  " Airline Themes
Plug 'bling/vim-bufferline'                            " Airline Buffer Line
Plug 'w0rp/ale'                                        " ALE
Plug 'ctrlpvim/ctrlp.vim'                              " Ctrl P
Plug 'raimondi/delimitmate'                            " Delimitmate
Plug 'tpope/vim-fugitive'                              " Fugitive for Git
Plug 'airblade/vim-gitgutter'                          " Gitgutter
Plug 'xolox/vim-misc'                                  " Misc Bundle
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' } " NERD tree open on ctrl-n
Plug 'jistr/vim-nerdtree-tabs'                         " NERD tabs
Plug 'scrooloose/nerdcommenter'                        " NERD Commenter
Plug 'reedes/vim-pencil'                               " Pencil
Plug 'klen/python-mode'                                " Py mode
Plug 'honza/vim-snippets'                              " Snippets for ultisnips 
Plug 'altercation/vim-colors-solarized'                " Solarized
Plug 'godlygeek/tabular'                               " Tabular
Plug 'SirVer/ultisnips'                                " Ultisnips Engine
Plug 'christoomey/vim-tmux-navigator'                  " vim-tmux-navigator

call plug#end()

" Plug Graveyard
" Plug 'flazz/vim-colorschemes' " Color schemes
" Plug 'xolox/vim-easytags'     " Easy Tags
" Plug 'shougo/neocomplete.vim' " Neocomplete
" Plug 'scrooloose/syntastic'   " Syntastic

" Remapping keys
let g:ctrlp_map = '<c-p>'     " CtrlP on Ctrl-P
let g:ctrlp_cmd = 'CtrlP'     " CtrlP on Ctrl-P
map <C-n> :NERDTreeToggle<CR> " Turn on NERD with Ctrl-n

" Move by 'display lines' rather than 'logical lines' if no v:count was
" provided.  When a v:count is provided, move by logical lines.
" Useful for writing in vim
nnoremap <expr> j v:count > 0 ? 'j' : 'gj'
xnoremap <expr> j v:count > 0 ? 'j' : 'gj'
nnoremap <expr> k v:count > 0 ? 'k' : 'gk'
xnoremap <expr> k v:count > 0 ? 'k' : 'gk'
" Ensure 'logical line' movement remains accessible.
nnoremap <silent> gj j
xnoremap <silent> gj j
nnoremap <silent> gk k
xnoremap <silent> gk k
" Ultisnips
" Trigger configuration. Do not use <tab> if you use https://github.com/Valloric/YouCompleteMe.
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<c-b>"
let g:UltiSnipsJumpBackwardTrigger="<c-z>"
" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"

" ColorScheme
set background=dark
colorscheme solarized
let g:airline_theme='solarized'
let g:solarized_darkgutter = 1 " Make the gutters darker than the background.

" Plugin Mods

" Airline 
set ttimeoutlen=10 " Fix the slight delay between switching vim modes

" Fixing airline symbols
let g:airline_powerline_fonts = 1
if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif

let g:airline_symbols.space = "\ua0"

set laststatus=2

let g:airline_skip_empty_sections = 1

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
