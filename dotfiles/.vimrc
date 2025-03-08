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
Plug 'git@github.com:chrisbra/matchit.git'
Plug 'git@github.com:dbakker/vim-paragraph-motion.git'
Plug 'git@github.com:easymotion/vim-easymotion.git'
Plug 'git@github.com:justinmk/vim-sneak.git'
Plug 'git@github.com:machakann/vim-highlightedyank.git'
Plug 'git@github.com:michaeljsmith/vim-indent-object.git'
Plug 'git@github.com:tommcdo/vim-exchange.git'
Plug 'git@github.com:tpope/vim-commentary.git'
Plug 'git@github.com:tpope/vim-surround.git'
Plug 'git@github.com:unblevable/quick-scope.git'
Plug 'git@github.com:vim-scripts/argtextobj.vim.git'
Plug 'git@github.com:echasnovski/mini.ai.git'
Plug 'git@github.com:kana/vim-textobj-function.git'
call plug#end()

if has('termguicolors')
  set termguicolors
endif

set background=dark
colorscheme sorbet
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

" let g:qs_primary_color = '#494949'
" let g:qs_secondary_color = '#707070'

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
set showmode
set noswapfile
set nrformats-=octal
set nu rnu
set number relativenumber
set ruler
set scrolloff=3
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
set cursorline

set rtp+=/usr/local/opt/fzf

" Make vim-sneak mappings more consistent in visual mode by making s go to next match and
" go to previous match, while keeping vim-surround functionality through z
" (mnemonics: vim-zurround) Explained in this GitHub issue:
" https://github.com/justinmk/vim-sneak/issues/268
" So now the behaviour is:
" - Normal: s and S to move with sneak
" - Visual: s and S to move with sneak, z to surround (zurround)
" - cs and ds: change/delete matching characters (), [], {}... with
"   vim-surround

" let g:surround_no_mappings= 1
" xmap <S-s> <Plug>Sneak_S
" xmap z <Plug>VSurround
" nmap yzz <Plug>Yssurround
" nmap yz  <Plug>Ysurround
" nmap dz  <Plug>Dsurround
" nmap cz  <Plug>Csurround
" omap s <Plug>Sneak_s
" S mapped with v to make it inclusive, similarly to other backward motions in
" my config (0 mapped to v0, ^ mapped to v^, etc)
" omap S v<Plug>Sneak_S

noremap <leader>y "*y
noremap <Leader>p "*p
" nnoremap <c-j> 5j
" nnoremap <c-k> 5k
nnoremap <c-j> :m .+1<CR>==
nnoremap <c-k> :m .-2<CR>==
xnoremap <c-j> 5j
xnoremap <c-k> 5k
nnoremap <c-h> :SidewaysLeft<cr>
nnoremap <c-l> :SidewaysRight<cr>
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
