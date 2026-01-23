-- =============================================================================
--  HYBRID NEOVIM CONFIG (VS CODE + TERMINAL)
--  Converted from legacy .vimrc to Lua
-- =============================================================================

-- 1. LAZY.NVIM BOOTSTRAP (Auto-installs plugin manager)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 2. PLUGIN SPECS
require("lazy").setup({
  -- SHARED PLUGINS (Work in both VSCode and Terminal)
  "tpope/vim-surround",
  "justinmk/vim-sneak",
  "vim-scripts/argtextobj.vim",
  "michaeljsmith/vim-indent-object",
  "tommcdo/vim-exchange",
  "dbakker/vim-paragraph-motion",
  "unblevable/quick-scope",
  "andymass/vim-matchup",

  -- TEXT OBJECTS (Explicit Dependencies to fix E117)
  {
    "kana/vim-textobj-entire",
    dependencies = { "kana/vim-textobj-user" },
  },
  {
    "kana/vim-textobj-function",
    dependencies = { "kana/vim-textobj-user" },
  },
  {
    "kana/vim-textobj-user", 
    lazy = false -- Force it to load immediately
  },

  -- TERMINAL ONLY PLUGINS (Skip in VS Code)
  {
    "echasnovski/mini.ai",
    cond = not vim.g.vscode, -- Only load if NOT in VS Code
    config = function() require("mini.ai").setup() end
  },
  {
    "easymotion/vim-easymotion",
    cond = not vim.g.vscode
  },
  {
    "tpope/vim-commentary",
    cond = not vim.g.vscode
  },
  {
    "folke/tokyonight.nvim", -- Modern theme to replace 'sorbet'
    lazy = false,
    priority = 1000,
    cond = not vim.g.vscode,
    config = function() vim.cmd([[colorscheme tokyonight]]) end
  }
})

-- 3. SHARED OPTIONS (The "Editing Logic")
local opt = vim.opt

-- Basic Behavior
opt.clipboard = "unnamedplus" -- Sync clipboard
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.scrolloff = 3
opt.showcmd = true
opt.expandtab = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.hidden = true
opt.cursorline = true

-- Keymaps Helper
local map = vim.keymap.set
-- vim.g.mapleader = " " -- Map <Leader> to Space

-- Shared Mappings
map('n', 'Y', 'y$') -- Make Y consistent with D and C
map('n', '<Leader>o', 'o<Esc>') -- Quick new line
map('n', '<Leader>O', 'O<Esc>')
map('n', '<Leader>y', '"*y') -- Yank to system clipboard (redundant if unnamedplus is on, but safe)
map('n', '<Leader>p', '"*p')

-- Moving Lines (Alt/Option + j/k behavior)
map('n', '<C-j>', ':m .+1<CR>==')
map('n', '<C-k>', ':m .-2<CR>==')
map('v', '<C-j>', ":m '>+1<CR>gv=gv")
map('v', '<C-k>', ":m '<-2<CR>gv=gv")
map('i', '<C-j>', '<Esc>:m .+1<CR>==gi')
map('i', '<C-k>', '<Esc>:m .-2<CR>==gi')

-- Sideways navigation (Assuming you had a plugin for this, kept placeholder)
map('n', '<C-h>', '<Left>')
map('n', '<C-l>', '<Right>')


-- =============================================================================
--  ENVIRONMENT SPECIFIC LOGIC
-- =============================================================================

if vim.g.vscode then
    -- --- VS CODE MODE ---
    local vscode = require('vscode')

    -- Use VS Code's native comment engine
    map({'n', 'x'}, 'gc', function() vscode.call('editor.action.commentLine') end)

    -- Refactoring / Rename
    map('n', '<Space>rn', function() vscode.call('editor.action.rename') end)
    
    -- Window Navigation (Matches your Control-h/l intent maybe?)
    map('n', '<C-h>', function() vscode.call('workbench.action.navigateLeft') end)
    map('n', '<C-l>', function() vscode.call('workbench.action.navigateRight') end)

else
    -- --- TERMINAL MODE ---
    
    -- Legacy UI Settings
    opt.termguicolors = true
    opt.background = "dark"
    opt.number = true
    opt.relativenumber = true
    opt.mouse = "a" -- Mouse support
    
    -- Statusline (Simple Lua version of your old one)
    local function git_branch()
        local branch = vim.fn.system("git rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '\n'")
        if branch ~= "" then return "  " .. branch .. " " end
        return ""
    end

    -- Basic statusline emulation
    opt.statusline = "%#Normal# %f %m %r " .. git_branch() .. "%= %y [%{&fileformat}] %p%% %l:%c"

    -- Netrw Settings
    vim.g.netrw_liststyle = 3
    vim.g.netrw_banner = 0
    vim.g.netrw_winsize = 25
    
    -- Strip Trailing Whitespace Command
    vim.api.nvim_create_user_command('StripWhitespace', function()
        local save_cursor = vim.fn.getpos(".")
        vim.cmd([[%s/\s\+$//e]])
        vim.fn.setpos('.', save_cursor)
    end, {})
    
    -- Jump to last cursor position
    vim.api.nvim_create_autocmd("BufReadPost", {
        callback = function()
            local mark = vim.api.nvim_buf_get_mark(0, '"')
            local lcount = vim.api.nvim_buf_line_count(0)
            if mark[1] > 0 and mark[1] <= lcount then
                pcall(vim.api.nvim_win_set_cursor, 0, mark)
            end
        end,
    })
end

