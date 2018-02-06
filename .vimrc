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
" Tabs
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set smarttab
set cursorline
set cursorcolumn
set encoding=utf8

filetype indent plugin on
" Leader
nnoremap <SPACE> <Nop>
nmap <SPACE> <leader>
map <space><space> <leader><leader>
nmap <silent> <leader>w :w <CR>
nmap <silent> <leader>wq :wq <CR>
nmap <silent> <leader>q :q <CR>
nmap <silent> <leader><Tab> :bn <CR>
nmap <silent> <leader>m :ALEToggle <CR>
nmap <silent> <leader>l :set relativenumber! <CR>
nmap <silent> <leader>s :Gstatus <CR>
nmap <silent> <leader>c :Gcommit <CR>
" fzf
nmap <leader>; :Buffers<CR>
nmap <leader>t :Files<CR>
nmap <leader>r :Tags<CR>
nmap <leader>y :Commits<CR>
nmap <leader>u :Commands<CR>
" Only do is autocmd is enabled
if has("autocmd")
  " Enable file type detection
  filetype on

  " Syntax of these languages is fussy over tabs Vs spaces
  autocmd FileType make setlocal ts=8 sts=8 sw=8 noexpandtab
  autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab

  " Customisations based on house-style (arbitrary)
  autocmd FileType html setlocal ts=2 sts=2 sw=2 expandtab
  autocmd FileType css setlocal ts=2 sts=2 sw=2 expandtab
  autocmd FileType javascript setlocal ts=4 sts=4 sw=4 noexpandtab

  " Treat .rss files as XML
  autocmd BufNewFile,BufRead *.rss setfiletype xml
endif

" Specify a directory for plugins
call plug#begin('~/.vim/plugged')

Plug 'mileszs/ack.vim'                                 " ACK
Plug 'bling/vim-airline'                               " Airline
Plug 'vim-airline/vim-airline-themes'                  " Airline Themes
Plug 'bling/vim-bufferline'                            " Airline Buffer Line
Plug 'w0rp/ale'                                        " ALE
Plug 'yuttie/comfortable-motion.vim'                   " Motion
Plug 'raimondi/delimitmate'                            " Delimitmate
Plug 'ryanoasis/vim-devicons'                          " DevIcons
Plug 'tpope/vim-fugitive'                              " Fugitive for Git
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'                                " fzf
Plug 'airblade/vim-gitgutter'                          " Gitgutter
Plug 'morhetz/gruvbox'                                 " Gruvbox
Plug 'othree/html5.vim'                                " HTLM5
Plug 'Yggdroot/indentLine'                             " Indent
Plug 'gregsexton/matchtag'                             " Matchtag
Plug 'xolox/vim-misc'                                  " Misc Bundle
Plug 'shougo/neocomplete.vim'                          " Neocomplete
Plug 'scrooloose/nerdcommenter'                        " NERD Commenter
Plug 'Xuyuanp/nerdtree-git-plugin'                     " NERD Git
Plug 'jistr/vim-nerdtree-tabs'                         " NERD tabs
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' } " NERD tree open on ctrl-n
Plug 'reedes/vim-pencil'                               " Pencil
Plug 'klen/python-mode'                                " Py mode
Plug 'honza/vim-snippets'                              " Snippets for ultisnips
Plug 'tomlion/vim-solidity'                            " Solidity Language Supprt
Plug 'tpope/vim-surround'                              " Surround
Plug 'godlygeek/tabular'                               " Tabular
Plug 'SirVer/ultisnips'                                " Ultisnips Engine
Plug 'mbbill/undotree'                                 " UndoTree
Plug 'christoomey/vim-tmux-navigator'                  " vim-tmux-navigator
                                                       " Web Dev
Plug 'KabbAmine/vCoolor.vim'                           " vCooler

call plug#end()

" Plug Graveyard
" Plug 'altercation/vim-colors-solarized' " Solarized
" Plug 'xolox/vim-easytags'               " Easy Tags
" Plug 'scrooloose/syntastic'             " Syntastic

" Plug 'nathanaelkane/vim-indent-guides'  " Vim Indent
" Plug 'ctrlpvim/ctrlp.vim'               " Ctrl P


map <C-n> :NERDTreeToggle<CR>  
nnoremap <C-b> :UndotreeToggle<cr>
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
map <leader>m :ALEToggle<CR>      " Turn on ALE with Ctrl-m
let g:ale_sign_column_always = 1
let g:ale_sign_error = '●' " Less aggressive than the default '>>'
let g:ale_sign_warning = '.'
let g:ale_set_quickfix = 1
let g:ale_open_list = 1
let g:ale_lint_on_save = 1
let g:ale_lint_on_text_changed = 0
let g:ale_lint_on_enter = 0
" ALE Fixers
let g:ale_fixers = {
\   'javascript': ['eslint'],
\}
let g:ale_fix_on_save = 1
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

" NERDTree
let NERDTreeShowHidden=1

" Indent
" let g:indent_guides_enable_on_vim_startup = 1
" set ts=4 sw=4 et
" let g:indent_guides_start_level=2
" let g:indent_guides_guide_size=2
