-- =============================================================================
--  HYBRID NEOVIM CONFIG (VS CODE + TERMINAL)
--  Updated: Smart Join Fallback + Cleaned Text Objects
-- =============================================================================
--
-- =============================================================================
--  CHEATSHEET
-- =============================================================================
--
--  MOTIONS / JUMPS  (flash.nvim + quick-scope)
--    f<char> / F<char>     Jump to char on screen — labels appear on duplicates
--    t<char> / T<char>     Till before char — labels on duplicates
--                          quick-scope underlines unique targets BEFORE pressing
--    ; / ,                 Repeat last f/F/t/T forward / backward
--    <leader>s             Flash jump (type any chars, then a label)
--    <leader>S             Flash treesitter (jump to syntax nodes / blocks)
--    r  (op-pending)       Remote flash, e.g. `dr<leader>s<chars>` deletes
--                          a region elsewhere without moving the cursor
--    During / or ?         Search labels appear — press a label to jump
--
--  TEXT OBJECTS  (use with d / c / y / v — e.g. `daf`, `vic`, `yi"`)
--    af / if               Function definition (treesitter)
--    ac / ic               Class (treesitter)
--    aa / ia               Argument (mini.ai)
--    ab / ib               Any bracket — () [] {} (mini.ai)
--    aq / iq               Any quote — " ' ` (mini.ai)
--    ae / ie               Entire buffer (mini.ai custom)
--    ai / ii               Around / inside indent scope (mini.indentscope)
--    Native: aw iw, as is, ap ip, a" i", a( i(, a{ i{ ...
--
--  TEXT OBJECT NAVIGATION  (treesitter)
--    ]f  [f                Next / prev function start
--    ]F  [F                Next / prev function end
--    ]c  [c                Next / prev class start
--    ]C  [C                Next / prev class end
--    [i  ]i                Top / bottom of indent scope
--
--  EDITING
--    J                     Smart join/split toggle (treesj, falls back to J)
--    Y                     Yank to end of line (= y$)
--    <leader>o / <leader>O Insert blank line below / above (no insert mode)
--    <leader>y / <leader>p Yank / paste using system clipboard (*)
--    <C-j> / <C-k>         Move current line down / up (n, v, i modes)
--
--  EXCHANGE  (substitute.nvim)
--    cx{motion}            Exchange operator — run twice to swap regions
--    cxx                   Exchange current line
--    X  (visual)           Exchange visual selection
--    cxc                   Cancel pending exchange
--
--  SURROUND  (vim-surround)
--    ys{motion}{char}      Add surround, e.g. `ysiw"` quotes a word
--    cs{old}{new}          Change surround, e.g. `cs"'` " → '
--    ds{char}              Delete surround, e.g. `ds(`
--    S{char}  (visual)     Surround visual selection
--
--  COMMENTS  (mini.comment — terminal only; VS Code uses native gc)
--    gcc                   Toggle current line
--    gc{motion}            Toggle motion, e.g. `gcap` paragraph
--    gc  (visual)          Toggle selection
--
--  VS CODE EXTRAS  (only active when running inside vscode-neovim)
--    gc                    VS Code's native comment toggle
--    <Space>rn             Rename symbol
--    <C-h> / <C-l>         Navigate to left / right editor group
--
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

  -- MINI.AI (Replaces argtextobj, textobj-entire)
  -- Note: `f` (function call) is disabled so `af`/`if` resolve to function
  -- *definitions* via nvim-treesitter-textobjects (matching IdeaVim's
  -- functiontextobj). Use `aa`/`ia` for arguments, `ab`/`ib` for brackets.
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
          f = false,
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

  -- QUICKSCOPE (Highlights unique f/F/t/T targets — always on)
  {
    'unblevable/quick-scope',
    cond = not vim.g.vscode,
    event = 'BufReadPost',
    init = function()
      vim.g.qs_max_chars = 1000
    end,
    config = function()
      vim.api.nvim_set_hl(0, 'QuickScopePrimary', { fg = '#afff5f', underline = true })
      vim.api.nvim_set_hl(0, 'QuickScopeSecondary', { fg = '#5fffff', underline = true })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    cond = not vim.g.vscode,
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    config = function()
      local status, ts = pcall(require, "nvim-treesitter.configs")
      if not status then return end
      ts.setup({
        ensure_installed = { "lua", "vim", "vimdoc", "query", "python", "javascript", "typescript", "go", "yaml", "json" },
        highlight = { enable = true },
        indent = { enable = true },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ['af'] = '@function.outer',
              ['if'] = '@function.inner',
              ['ac'] = '@class.outer',
              ['ic'] = '@class.inner',
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = { [']f'] = '@function.outer', [']c'] = '@class.outer' },
            goto_next_end = { [']F'] = '@function.outer', [']C'] = '@class.outer' },
            goto_previous_start = { ['[f'] = '@function.outer', ['[c'] = '@class.outer' },
            goto_previous_end = { ['[F'] = '@function.outer', ['[C'] = '@class.outer' },
          },
        },
      })
    end
  },

  -- =========================
  --  IDE INFRASTRUCTURE
  -- =========================

  -- MASON: Package manager for LSPs, linters, and formatters
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    cond = not vim.g.vscode,
    opts = { ensure_installed = { "shfmt" } },
  },

  -- MASON LSPCONFIG: Bridges the gap between mason and nvim-lspconfig
  {
    "williamboman/mason-lspconfig.nvim",
    cond = not vim.g.vscode,
    opts = {
      ensure_installed = {
        "pyright",
        "ts_ls",
        "gopls",
        "bashls",
      },
    },
  },

  -- NVIM LSPCONFIG: The native client configuration
  {
    "neovim/nvim-lspconfig",
    cond = not vim.g.vscode,
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "saghen/blink.cmp" },
    config = function()
      local lspconfig = require("lspconfig")
      local blink = require("blink.cmp")

      local capabilities = blink.get_lsp_capabilities()

      local servers = { "pyright", "ts_ls", "gopls", "bashls" }
      for _, server in ipairs(servers) do
        lspconfig[server].setup({
          capabilities = capabilities,
        })
      end

      -- NOTE: Java (jdtls) is handled separately below for enterprise scaling
    end,
  },

  -- BLINK.CMP: High-performance completion engine
  {
    'saghen/blink.cmp',
    version = '*',
    cond = not vim.g.vscode,
    event = "InsertEnter",
    dependencies = 'rafamadriz/friendly-snippets',
    opts = {
      keymap = { preset = 'default' },
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = 'mono'
      },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
      },
    },
  },

  -- FZF-LUA: Ultra-fast project fuzzy finder
  {
    "ibhagwan/fzf-lua",
    cond = not vim.g.vscode,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    config = function()
      pcall(function() require("fzf-lua").setup({ "fzf-native" }) end)
    end,
  },

  -- OIL.NVIM: Edit the file system like a text buffer
  {
    'stevearc/oil.nvim',
    cond = not vim.g.vscode,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      columns = { "icon" },
      view_options = { show_hidden = true },
    },
  },

  -- CONFORM.NVIM: Asynchronous formatter tool
  {
    "stevearc/conform.nvim",
    cond = not vim.g.vscode,
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      formatters_by_ft = {
        javascript = { "prettier" },
        typescript = { "prettier" },
        python = { "black" },
        go = { "gofmt", "goimports" },
        sh = { "shfmt" },
      },
      format_on_save = { timeout_ms = 500, lsp_format = "fallback" },
    },
  },

  -- NVIM-JDTLS: Specialized configuration extension for Java
  {
    "mfussenegger/nvim-jdtls",
    cond = not vim.g.vscode,
    ft = "java",
    config = function()
      local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
      local workspace_dir = vim.fn.stdpath("data") .. "/site/java/workspace-root/" .. project_name

      local config = {
        cmd = {
          "jdtls",
          "-data", workspace_dir,
          "--jvm-arg=-Xms2G",
          "--jvm-arg=-Xmx6G",
          "--jvm-arg=-XX:+UseG1GC",
        },
        root_dir = require('jdtls.setup').find_root({'.git', 'mvnw', 'gradlew', 'pom.xml'}),
        capabilities = require('blink.cmp').get_lsp_capabilities(),
      }
      require('jdtls').start_or_attach(config)
    end
  },

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

    -- LSP Telemetry & Code Intelligence Navigation
    vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(event)
            local opts = { buffer = event.buf }

            map('n', 'gd', vim.lsp.buf.definition, opts)          -- Go to definition
            map('n', 'gr', function() local ok, f = pcall(require, 'fzf-lua') if ok then f.lsp_references() else vim.lsp.buf.references() end end, opts) -- Find references (fzf fallback)
            map('n', 'K', vim.lsp.buf.hover, opts)               -- Documentation popup
            map('n', '<space>rn', vim.lsp.buf.rename, opts)       -- Rename symbol
            map({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts) -- Code Actions (Quick-fix)
        end,
    })

    -- Project Search & Navigation (Fzf-lua)
    local ok_fzf, fzf = pcall(require, 'fzf-lua')
    if ok_fzf then
      map('n', '<leader><space>', function() fzf.files() end, { desc = "Find Project Files" })
      map('n', '<leader>ff', function() fzf.live_grep() end, { desc = "Search Text Globally" })
      map('n', '<leader>fb', function() fzf.buffers() end, { desc = "List Active Buffers" })
      map('n', '<leader>fh', function() fzf.help_tags() end, { desc = "Search Documentation Help" })
    else
      -- fallback (if fzf-lua not available)
      map('n', '<leader><space>', function() vim.cmd('echo "fzf-lua not available"') end, { desc = "Find Project Files (missing fzf)" })
    end

    -- File System Workspace Navigation (Oil.nvim)
    map("n", "-", "<CMD>Oil<CR>", { desc = "Open Parent Directory Buffer" })

    -- Statusline (git branch is cached per-buffer; refreshed on enter/focus/shell)
    local function refresh_git_branch()
        local branch = vim.fn.system("git rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '\n'")
        vim.b.git_branch = branch ~= "" and ("  " .. branch .. " ") or ""
    end
    _G.statusline_git_branch = function() return vim.b.git_branch or "" end
    vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "ShellCmdPost" }, {
        callback = refresh_git_branch,
    })
    opt.statusline = "%#Normal# %f %m %r %{v:lua.statusline_git_branch()}%= %y [%{&fileformat}] %p%% %l:%c"

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

