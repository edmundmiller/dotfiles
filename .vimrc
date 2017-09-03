set nocompatible " Use Vim settings instead of Vi Must be first

" General Config
set mouse=a                " Mouse use
set history=1000           " Reduce Vim's short-term memory loss
set number                 " Numbers in gutter
set spell                  " Spell checking
set hidden                 " Allows current buffer to be moved to background without writing to disk
set termguicolors
set clipboard=unnamed
syntax enable              " Turns on Syntax
runtime macros/matchit.vim " Allows % to switch between if/else/etc.
set wildmode=list:longest  " <TAB> in command shows completion
let mapleader = "<SPACE>"  " Sets leader to <Space>
" Tabs
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set smarttab
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
Plug 'morhetz/gruvbox'                                 " Gruvbox
Plug 'xolox/vim-misc'                                  " Misc Bundle
Plug 'shougo/neocomplete.vim'                          " Neocomplete
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' } " NERD tree open on ctrl-n
Plug 'jistr/vim-nerdtree-tabs'                         " NERD tabs
Plug 'scrooloose/nerdcommenter'                        " NERD Commenter
Plug 'reedes/vim-pencil'                               " Pencil
Plug 'klen/python-mode'                                " Py mode
Plug 'honza/vim-snippets'                              " Snippets for ultisnips
Plug 'godlygeek/tabular'                               " Tabular
Plug 'SirVer/ultisnips'                                " Ultisnips Engine
Plug 'christoomey/vim-tmux-navigator'                  " vim-tmux-navigator
                                                       " Web Dev
Plug 'KabbAmine/vCoolor.vim'                           " vCooler

call plug#end()

" Plug Graveyard
" Plug 'altercation/vim-colors-solarized' " Solarized
" Plug 'xolox/vim-easytags'               " Easy Tags
" Plug 'scrooloose/syntastic'             " Syntastic

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
colorscheme gruvbox
let g:airline_theme='gruvbox'
let g:gruvbox_darkgutter = 1 " Make the gutters darker than the background.
" --------- Plugin Mods -------------
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
let g:airline#extensions#ale#enabled = 1
" ALE
let g:ale_sign_column_always = 1
let g:ale_sign_error = '>>'
let g:ale_sign_warning = '--'
let g:ale_set_quickfix = 1
let g:ale_open_list = 1
let g:ale_lint_on_save = 1
let g:ale_lint_on_text_changed = 0
" Neocomplete
" Disable AutoComplPop.
let g:acp_enableAtStartup = 0
" Use neocomplete.
let g:neocomplete#enable_at_startup = 1
" Use smartcase.
let g:neocomplete#enable_smart_case = 1
" Set minimum syntax keyword length.
let g:neocomplete#sources#syntax#min_keyword_length = 3

" Define dictionary.
let g:neocomplete#sources#dictionary#dictionaries = {
    \ 'default' : '',
    \ 'vimshell' : $HOME.'/.vimshell_hist',
    \ 'scheme' : $HOME.'/.gosh_completions'
        \ }

" Define keyword.
if !exists('g:neocomplete#keyword_patterns')
    let g:neocomplete#keyword_patterns = {}
endif
let g:neocomplete#keyword_patterns['default'] = '\h\w*'

" Plugin key-mappings.
inoremap <expr><C-g>     neocomplete#undo_completion()
inoremap <expr><C-l>     neocomplete#complete_common_string()

" Recommended key-mappings.
" <CR>: close popup and save indent.
inoremap <silent> <CR> <C-r>=<SID>my_cr_function()<CR>
function! s:my_cr_function()
  return (pumvisible() ? "\<C-y>" : "" ) . "\<CR>"
  " For no inserting <CR> key.
  "return pumvisible() ? "\<C-y>" : "\<CR>"
endfunction
" <TAB>: completion.
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
" <C-h>, <BS>: close popup and delete backword char.
inoremap <expr><C-h> neocomplete#smart_close_popup()."\<C-h>"
inoremap <expr><BS> neocomplete#smart_close_popup()."\<C-h>"
" Close popup by <Space>.
"inoremap <expr><Space> pumvisible() ? "\<C-y>" : "\<Space>"

" AutoComplPop like behavior.
"let g:neocomplete#enable_auto_select = 1

" Shell like behavior(not recommended).
"set completeopt+=longest
"let g:neocomplete#enable_auto_select = 1
"let g:neocomplete#disable_auto_complete = 1
"inoremap <expr><TAB>  pumvisible() ? "\<Down>" : "\<C-x>\<C-u>"

" Enable omni completion.
autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags

" Enable heavy omni completion.
if !exists('g:neocomplete#sources#omni#input_patterns')
  let g:neocomplete#sources#omni#input_patterns = {}
endif
"let g:neocomplete#sources#omni#input_patterns.php = '[^. \t]->\h\w*\|\h\w*::'
"let g:neocomplete#sources#omni#input_patterns.c = '[^.[:digit:] *\t]\%(\.\|->\)'
"let g:neocomplete#sources#omni#input_patterns.cpp = '[^.[:digit:] *\t]\%(\.\|->\)\|\h\w*::'

" For perlomni.vim setting.
" https://github.com/c9s/perlomni.vim
let g:neocomplete#sources#omni#input_patterns.perl = '\h\w*->\h\w*\|\h\w*::'
