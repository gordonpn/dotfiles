"                                        _/
"     _/_/_/    _/_/    _/  _/_/    _/_/_/    _/_/    _/_/_/
"  _/    _/  _/    _/  _/_/      _/    _/  _/    _/  _/    _/
" _/    _/  _/    _/  _/        _/    _/  _/    _/  _/    _/
"  _/_/_/    _/_/    _/          _/_/_/    _/_/    _/    _/
"     _/
"_/_/

if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
Plug 'NLKNguyen/papercolor-theme'
Plug 'dbakker/vim-paragraph-motion'
Plug 'easymotion/vim-easymotion'
Plug 'editorconfig/editorconfig-vim'
Plug 'jiangmiao/auto-pairs'
Plug 'machakann/vim-highlightedyank'
Plug 'michaeljsmith/vim-indent-object'
Plug 'sheerun/vim-polyglot'
Plug 'tommcdo/vim-exchange'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'vim-scripts/argtextobj.vim'
Plug 'yggdroot/indentline'
call plug#end()

if has('termguicolors')
  set termguicolors
endif

set background=light
let g:PaperColor_Theme_Options = {
  \   'theme': {
  \     'default': {
  \       'allow_bold': 0,
  \       'allow_italic': 0,
  \       'transparent_background': 1
  \     }
  \   }
  \ }
colorscheme PaperColor
highlight Normal     ctermbg=NONE guibg=NONE
highlight LineNr     ctermbg=NONE guibg=NONE
highlight SignColumn ctermbg=NONE guibg=NONE

let g:EasyMotion_smartcase=1
let g:EasyMotion_use_smartsign_us=1

set conceallevel=1
let g:indentLine_conceallevel=1
let g:indentLine_char_list = ['|', '¦', '┆', '┊']
let g:indentLine_enabled=1

let g:vim_json_conceal=0

let g:highlightedyank_highlight_duration = "1000"

set autoindent
set backspace=indent,eol,start
set display=truncate
set hidden
set history=200
set hlsearch
set ignorecase
set incsearch
set linebreak
set mouse=
set nocompatible
set noro
set noshowmode
set noswapfile
set nrformats-=octal
set nu rnu
set number relativenumber
set ruler
set scrolloff=15
set showcmd
set showmatch
set smartcase
set tabstop=2 shiftwidth=2 expandtab
set title
set ttimeout
set ttimeoutlen=100
set ttyfast
set ttymouse=
set undolevels=1000
set wildmenu

set rtp+=/usr/local/opt/fzf

noremap <leader>y "*y
noremap <Leader>p "*p
" nnoremap <c-j> 5j
" nnoremap <c-k> 5k
nnoremap <c-j> :m .+1<CR>==
nnoremap <c-k> :m .-2<CR>==
xnoremap <c-j> 5j
xnoremap <c-k> 5k
" inoremap <c-k> <up>
" inoremap <c-j> <down>
inoremap <c-h> <left>
inoremap <c-l> <right>
inoremap <c-j> <Esc>:m .+1<CR>==gi
inoremap <c-k> <Esc>:m .-2<CR>==gi
vnoremap <c-j> :m '>+1<CR>gv=gv
vnoremap <c-k> :m '<-2<CR>gv=gv

autocmd InsertEnter * set cul
autocmd InsertLeave * set nocul
let &t_SI = "\<Esc>]50;CursorShape=1\x7"
let &t_SR = "\<Esc>]50;CursorShape=2\x7"
let &t_EI = "\<Esc>]50;CursorShape=0\x7"

let g:netrw_liststyle = 3
let g:netrw_banner = 0
let g:netrw_browse_split = 4
let g:netrw_altv = 1
let g:netrw_winsize = 25
" augroup ProjectDrawer
"   autocmd!
"   autocmd VimEnter * :Vexplore
" augroup END

set wildignore+=*.pyc,*.pyo,*/__pycache__/*
set wildignore+=*.swp,~*
set wildignore+=*.zip,*.tar

function! GitBranch()
  return system("git rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '\n'")
endfunction

function! StatuslineGit()
  let l:branchname = GitBranch()
  return strlen(l:branchname) > 0?'  '.l:branchname.' ':''
endfunction

set statusline=
set statusline+=%#DiffAdd#%{(mode()=='n')?'\ \ NORMAL\ ':''}
set statusline+=%#DiffChange#%{(mode()=='i')?'\ \ INSERT\ ':''}
set statusline+=%#DiffDelete#%{(mode()=='r')?'\ \ RPLACE\ ':''}
set statusline+=%#Visual#%{(mode()=='v')?'\ \ VISUAL\ ':''}
set statusline+=%#PmenuSel#
set statusline+=%{StatuslineGit()}
set statusline+=%#LineNr#
set statusline+=\ %f
set statusline+=\ %r
set statusline+=\ %m
" right align
set statusline+=\ %=
set statusline+=%#CursorColumn#
set statusline+=\ %y
set statusline+=\ %{&fileencoding?&fileencoding:&encoding}
set statusline+=\[%{&fileformat}\]
set statusline+=\ %p%%
set statusline+=\ %l:%c

function! StripTrailingWhitespace()
  if !&binary && &filetype != 'diff'
    normal mz
    normal Hmy
    %s/\s\+$//e
    normal 'yz<CR>
    normal `z
  endif
endfunction

" The default vimrc file.
"
" When started as "evim", evim.vim will already have done these settings.
if v:progname =~? "evim"
  finish
endif

" Bail out if something that ran earlier, e.g. a system wide vimrc, does not
" want Vim to use these default values.
if exists('skip_defaults_vim')
  finish
endif

" Don't use Ex mode, use Q for formatting.
" Revert with ":unmap Q".
map Q gq

" CTRL-U in insert mode deletes a lot.  Use CTRL-G u to first break undo,
" so that you can undo CTRL-U after inserting a line break.
" Revert with ":iunmap <C-U>".
inoremap <C-U> <C-G>u<C-U>

" In many terminal emulators the mouse works just fine.  By enabling it you
" can position the cursor, Visually select and scroll with the mouse.
" Only xterm can grab the mouse events when using the shift key, for other
" terminals use ":", select text and press Esc.
if has('mouse')
  if &term =~ 'xterm'
    set mouse=a
  else
    set mouse=nvi
  endif
endif

" Switch syntax highlighting on when the terminal has colors or when using the
" GUI (which always has colors).
if &t_Co > 2 || has("gui_running")
  " Revert with ":syntax off".
  syntax on

  " I like highlighting strings inside C comments.
  " Revert with ":unlet c_comment_strings".
  let c_comment_strings=1
endif

" Only do this part when Vim was compiled with the +eval feature.
if 1

  " Enable file type detection.
  " Use the default filetype settings, so that mail gets 'tw' set to 72,
  " 'cindent' is on in C files, etc.
  " Also load indent files, to automatically do language-dependent indenting.
  " Revert with ":filetype off".
  filetype plugin indent on

  " Put these in an autocmd group, so that you can revert them with:
  " ":augroup vimStartup | au! | augroup END"
  augroup vimStartup
    au!

    " When editing a file, always jump to the last known cursor position.
    " Don't do it when the position is invalid, when inside an event handler
    " (happens when dropping a file on gvim) and for a commit message (it's
    " likely a different one than last time).
    autocmd BufReadPost *
      \ if line("'\"") >= 1 && line("'\"") <= line("$") && &ft !~# 'commit'
      \ |   exe "normal! g`\""
      \ | endif

  augroup END

endif

" Convenient command to see the difference between the current buffer and the
" file it was loaded from, thus the changes you made.
" Only define it when not defined already.
" Revert with: ":delcommand DiffOrig".
if !exists(":DiffOrig")
  command DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | diffthis | wincmd p | diffthis
endif

if has('langmap') && exists('+langremap')
  " Prevent that the langmap option applies to characters that result from a
  " mapping.  If set (default), this may break plugins (but it's backward
  " compatible).
  set nolangremap
endif
