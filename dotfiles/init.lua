-- =============================================================================
--  HYBRID NEOVIM CONFIG (VS CODE + TERMINAL)
--  Updated: Smart Join Fallback + Cleaned Text Objects
-- =============================================================================

-- 1. LAZY.NVIM BOOTSTRAP
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
  -- ===========================================================================
  --  SHARED PLUGINS (Enabled in both VS Code & Terminal)
  -- ===========================================================================
  
  "tpope/vim-surround",
  {
    'andymass/vim-matchup',
    event = 'BufReadPost',
    config = function()
      vim.g.matchup_matchparen_offscreen = { method = 'popup' }
    end,
  },

  -- SMART JOIN (Replaces ideajoin)
  {
    'Wansmer/treesj',
    keys = {
      {
        'J',
        function()
          local tsj = require('treesj')
          local has_parser = pcall(vim.treesitter.get_parser, 0)
          if not has_parser then
            vim.cmd('normal! J')
          else
            tsj.toggle()
          end
        end,
        desc = 'Join Toggle (Smart Fallback)',
      },
    },
    cmd = { 'TSJToggle' },
    opts = { use_default_keymaps = false, max_join_length = 120 },
  },

  -- FLASH (Replaces Easymotion & Sneak)
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = {},
    keys = {
      { '<leader>s', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash Jump' },
      { '<leader>S', mode = { 'n', 'x', 'o' }, function() require('flash').treesitter() end, desc = 'Flash Treesitter' },
      { 'r', mode = 'o', function() require('flash').remote() end, desc = 'Remote Flash' },
    },
  },

  -- SUBSTITUTE (Replaces vim-exchange)
  {
    'gbprod/substitute.nvim',
    event = 'VeryLazy',
    config = function()
      local sub = require('substitute')
      sub.setup({
         exchange = {
            motion = false,
            use_mode_changed_on_choice = true,
         }
      })
      local ex = require('substitute.exchange')
      vim.keymap.set('n', 'cx', ex.operator, { desc = 'Exchange Operator' })
      vim.keymap.set('n', 'cxx', ex.line, { desc = 'Exchange Line' })
      vim.keymap.set('x', 'X', ex.visual, { desc = 'Exchange Selection' })
      vim.keymap.set('n', 'cxc', ex.cancel, { desc = 'Exchange Cancel' })
    end,
  },

  -- MINI.AI (Replaces argtextobj, textobj-entire, textobj-function)
  {
    "echasnovski/mini.ai",
    event = "VeryLazy",
    config = function()
      require("mini.ai").setup({
        custom_textobjects = {
          -- Mimic "textobj-entire" (ae / ie)
          e = function()
            local from = { line = 1, col = 1 }
            local to = {
              line = vim.fn.line('$'),
              col = math.max(vim.fn.getline('$'):len(), 1)
            }
            return { from = from, to = to }
          end,
        },
      }) 
    end
  },

  -- MINI.INDENTSCOPE (Replaces vim-indent-object)
  -- Provides 'ii' (inner indent) and 'ai' (around indent)
  {
    "echasnovski/mini.indentscope",
    event = "VeryLazy",
    -- VS Code does not need visual indent guides, but we want the OBJECTS.
    -- If you find the guides distracting in terminal, set `draw = { enable = false }`
    opts = {
      -- symbol = "│",
      options = { try_as_border = true },
      mappings = {
        object_scope = 'ii',
        object_scope_with_border = 'ai',
        goto_top = '[i',
        goto_bottom = ']i',
      },
    },
  },

  -- ===========================================================================
  --  TERMINAL ONLY PLUGINS (Skip in VS Code)
  -- ===========================================================================
  
  -- COMMENTING
  {
    "echasnovski/mini.comment",
    version = "*",
    cond = not vim.g.vscode,
    event = "VeryLazy",
    config = function() require("mini.comment").setup() end
  },

  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    cond = not vim.g.vscode,
    config = function() vim.cmd([[colorscheme tokyonight]]) end
  },

  {
    "nvim-treesitter/nvim-treesitter",
    cond = not vim.g.vscode,
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function() 
      local status, ts = pcall(require, "nvim-treesitter.configs")
      if not status then return end
      ts.setup({
        ensure_installed = { "lua", "vim", "vimdoc", "query", "python", "javascript", "typescript", "go", "yaml", "json" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end
  }
})

-- 3. SHARED OPTIONS
local opt = vim.opt

-- Basic Behavior
opt.clipboard = "unnamedplus"
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

-- Shared Mappings
map('n', 'Y', 'y$')
map('n', '<Leader>o', 'o<Esc>')
map('n', '<Leader>O', 'O<Esc>')
map('n', '<Leader>y', '"*y')
map('n', '<Leader>p', '"*p')

-- Moving Lines
map('n', '<C-j>', ':m .+1<CR>==')
map('n', '<C-k>', ':m .-2<CR>==')
map('v', '<C-j>', ":m '>+1<CR>gv=gv")
map('v', '<C-k>', ":m '<-2<CR>gv=gv")
map('i', '<C-j>', '<Esc>:m .+1<CR>==gi')
map('i', '<C-k>', '<Esc>:m .-2<CR>==gi')

-- Sideways navigation
map('n', '<C-h>', '<Left>')
map('n', '<C-l>', '<Right>')

-- =============================================================================
--  ENVIRONMENT SPECIFIC LOGIC
-- =============================================================================

if vim.g.vscode then
    -- --- VS CODE MODE ---
    local vscode = require('vscode')

    -- Native Comments
    map({'n', 'x'}, 'gc', function() vscode.call('editor.action.commentLine') end)

    -- Refactoring / Rename
    map('n', '<Space>rn', function() vscode.call('editor.action.rename') end)

    -- Window Navigation
    map('n', '<C-h>', function() vscode.call('workbench.action.navigateLeft') end)
    map('n', '<C-l>', function() vscode.call('workbench.action.navigateRight') end)

else
    -- --- TERMINAL MODE ---
    opt.termguicolors = true
    opt.background = "dark"
    opt.number = true
    opt.relativenumber = true
    opt.mouse = "a"

    -- Statusline
    local function git_branch()
        local branch = vim.fn.system("git rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '\n'")
        if branch ~= "" then return "  " .. branch .. " " end
        return ""
    end
    opt.statusline = "%#Normal# %f %m %r " .. git_branch() .. "%= %y [%{&fileformat}] %p%% %l:%c"

    -- Netrw
    vim.g.netrw_liststyle = 3
    vim.g.netrw_banner = 0
    vim.g.netrw_winsize = 25

    -- Strip Whitespace
    vim.api.nvim_create_user_command('StripWhitespace', function()
        local save_cursor = vim.fn.getpos(".")
        vim.cmd([[%s/\s\+$//e]])
        vim.fn.setpos('.', save_cursor)
    end, {})

    -- Restore Cursor
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

