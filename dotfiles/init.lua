-- =============================================================================
--  HYBRID NEOVIM CONFIG (VS CODE + TERMINAL)
--  Updated: Smart Join Fallback + Cleaned Text Objects + IDE Enhancements
-- =============================================================================
--
-- =============================================================================
--  CHEATSHEET (core navigation, editing, IDE features)
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
-- -----------------------------------------------------------------------------
--  NEW IDE FEATURES (keys / behavior)
--
--  GIT (gitsigns)
--    ─ Inline markers show added/changed/deleted lines
--    ]h / [h              Jump next / prev git hunk
--    <leader>hp           Preview hunk
--    <leader>hb           Blame current line (full)
--
--  TERMINAL & GIT GUI (toggleterm + lazygit)
--    <C-\>               Toggle floating terminal
--    <leader>gg           Toggle LazyGit UI (if installed)
--
--  WORKSPACE PROBLEMS (trouble.nvim)
--    <leader>xx           Toggle project diagnostics (Trouble)
--    <leader>xb           Show buffer diagnostics in Trouble
--    <leader>xq           Toggle quickfix list in Trouble
--
--  TEST RUNNER (neotest)
--    <leader>tr           Run nearest test
--    <leader>tf           Run tests in current file
--    <leader>ts           Toggle test summary tree
--
--  BREADCRUMBS (dropbar)
--    Dropbar shows structured breadcrumbs (Class > Method > Block)
--
--  DEBUGGING (nvim-dap + dap-ui)
--    <leader>db           Toggle breakpoint
--    <leader>dc           Start / Continue
--    <leader>di           Step Into
--    <leader>do           Step Over
--    <leader>du           Toggle DAP UI panels
--
-- -----------------------------------------------------------------------------
--  QUICK LSP REFERENCE
--    gd                    Go to definition
--    gr                    Find references (fzf-lua fallback)
--    K                     Hover documentation
--    <space>rn             Rename symbol
--    <space>ca             Code action (quick fix)
--
--  COMPLETION (blink.cmp)
--    Trigger: type or <C-Space> (Insert mode)
--    Navigate: <C-n> / <C-p>
--    Accept: <CR>
--    Snippet expand/jump: <Tab> / <S-Tab> (depends on snippet engine)
--
--  FORMATTING (conform.nvim)
--    Auto-format on save for supported ft: JS/TS/Python/Go/SH
--    Command: :ConformInfo
--
--  PROJECT NAVIGATION (fzf-lua)
--    <leader><space>       Find project files
--    <leader>ff            Live grep across project
--    <leader>fb            Buffers list
--    <leader>fh            Help tags
--
--  FILESYSTEM (oil.nvim)
--    -                     Open parent directory buffer (edit directory like a file)
--    Rename/move: edit the file line and save
--
--  SNIPPETS
--    Use rafamadriz/friendly-snippets with blink.cmp; expand via snippet key (Tab)
--
--  SEARCH & REPLACE
--    / ? n N               Search forward/back and repeat
--    :%s/foo/bar/gc        Replace with confirmation
--    <leader>ff            Use fzf live_grep for project-wide searches
--
--  REGISTERS & MACROS
--    "xy                  Use register x for yank/paste
--    q{reg} ... q         Record macro to register
--    @{reg}               Play macro
--
--  FOLDING
--    Use treesitter for reliable folds; zc/zo to close/open; za to toggle
--
--  SESSIONS & WORKSPACES
--    vim.fn.stdpath('data')/site/java/workspace-root/... used for jdtls workspaces
--    Use :mksession / :source to save/restore layouts if desired
--
--  MASON / SERVERS
--    :Mason                Open Mason UI
--    :MasonInstall <pkg>   Install server manually (e.g. lua-language-server)
--
--  PERFORMANCE TIPS
--    - Keep heavy filetypes/plugins lazy-loaded (cond = not vim.g.vscode)
--    - Increase jdtls heap for Java projects (configured in jdtls plugin)

--  UI POLISH (dressing.nvim + noice.nvim)
--    LSP rename / code action prompts appear as floating UI instead of
--    raw bottom-line input; command-line and notify popups are also styled.

--  AUTO-PAIRS / TAGS (nvim-autopairs + nvim-ts-autotag)
--    Brackets, quotes, and JSX/HTML tags close automatically while typing.

--  TODO TRACKING (todo-comments.nvim)
--    ]t / [t              Jump next / prev TODO/FIXME/HACK/NOTE
--    <leader>st           Search workspace annotations

--  DATABASE UI
--    (Skipped) Dadbod was intentionally omitted from this setup.
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
local plugin_specs = {
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
    "rebelot/kanagawa.nvim",
    name = "kanagawa",
    lazy = false,
    priority = 1000,
    cond = not vim.g.vscode,
    config = function()
      require("kanagawa").setup({
        theme = "dragon",
        undercurl = true,
        commentStyle = { italic = true },
      })

      -- FORCE TRANSPARENCY BY CLEARING HIGHLIGHT GROUPS DIRECTLY
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          local hl_groups = {
            "Normal",       -- Core editor workspace background
            "NormalNC",     -- Non-current window backgrounds
            "SignColumn",   -- Git signs and diagnostic column
            "FoldColumn",   -- Code folding column
            "LineNr",       -- Line numbers
            "CursorLineNr", -- Active line number
            "EndOfBuffer",  -- The '~' characters at the bottom of empty files
          }
          for _, group in ipairs(hl_groups) do
            vim.api.nvim_set_hl(0, group, { bg = "none" })
          end
        end,
      })

      vim.cmd.colorscheme("kanagawa")
    end
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

  -- GITSIGNS: Inline +/-/~ gutter markers, hunk navigation and preview
  {
    "lewis6991/gitsigns.nvim",
    cond = not vim.g.vscode,
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map("n", "]h", function() gs.nav_hunk("next") end, "Next git hunk")
        map("n", "[h", function() gs.nav_hunk("prev") end, "Previous git hunk")
        map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
      end,
    },
  },

  -- LAZYGIT: Floating lazygit terminal inside Neovim
  {
    "kdheepak/lazygit.nvim",
    cond = not vim.g.vscode,
    cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "Toggle LazyGit Floating Window" },
    },
  },

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
    opts = function()
      local servers = { "pyright", "ts_ls", "bashls", "yamlls", "jsonls", "dockerls", "lua_ls" }
      if vim.fn.executable("go") == 1 then table.insert(servers, "gopls") end
      return { ensure_installed = servers }
    end,
  },

  -- NVIM LSPCONFIG: The native client configuration
  {
    "neovim/nvim-lspconfig",
    cond = not vim.g.vscode,
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "saghen/blink.cmp", "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      local ok_mason_lsp, mason_lspconfig = pcall(require, 'mason-lspconfig')
      local ok_lspconfig, lspconfig = pcall(require, 'lspconfig')
      if not ok_lspconfig then return end

      local blink = require("blink.cmp")
      local capabilities = blink.get_lsp_capabilities()

      if ok_mason_lsp then
        for _, server_name in ipairs(mason_lspconfig.get_installed_servers()) do
          lspconfig[server_name].setup({ capabilities = capabilities })
        end
      end
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

  -- AUTOPAIRS: Auto-close brackets, quotes, and pairs
  {
    "windwp/nvim-autopairs",
    cond = not vim.g.vscode,
    event = "InsertEnter",
    opts = {},
  },

  -- TS-AUTOTAG: Auto-close and rename HTML/JSX/TSX tags
  {
    "windwp/nvim-ts-autotag",
    cond = not vim.g.vscode,
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact", "html", "xml" },
    opts = {},
  },

  -- DRESSING: Floating inputs for rename, code actions, and other prompts
  {
    "stevearc/dressing.nvim",
    cond = not vim.g.vscode,
    event = "VeryLazy",
    opts = {},
  },

  -- NOICE: Better command line, messages, and LSP popups
  {
    "folke/noice.nvim",
    cond = not vim.g.vscode,
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
      },
    },
  },

  -- TODO-COMMENTS: Highlight and search TODO/FIXME/HACK notes
  {
    "folke/todo-comments.nvim",
    cond = not vim.g.vscode,
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next Todo Comment" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous Todo Comment" },
      { "<leader>st", "<cmd>TodoQuickFix<cr>", desc = "Search Workspace TODOs" },
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
        root_dir = require('jdtls.setup').find_root({
          '.git', 'mvnw', 'gradlew', 'pom.xml',
          '.bemol', 'Config', 'packageInfo',
        }),
        capabilities = require('blink.cmp').get_lsp_capabilities(),
      }
      require('jdtls').start_or_attach(config)
    end
  },

  -- TOGGLETERM: Managed terminal layers inside Neovim
  {
    "akinsho/toggleterm.nvim",
    version = '*',
    cond = not vim.g.vscode,
    event = "VeryLazy",
    opts = {
      size = 20,
      open_mapping = [[<C-\>]],
      direction = 'float',
      float_opts = { border = 'curved' }
    }
  },

  -- NEOTEST: Interactive test runner framework
  {
    "nvim-neotest/neotest",
    cond = not vim.g.vscode,
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "nvim-neotest/neotest-go",
      "rcarriga/neotest-python",
      "haydenmeade/neotest-jest",
    },
    keys = {
      { "<leader>tr", function() require("neotest").run.run() end, desc = "Run Nearest Test" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run Current File Tests" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle Test Summary Tree" },
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-go"),
          require("neotest-python"),
          require("neotest-jest")({ jestConfigFile = "jest.config.ts" }),
        }
      })
    end
  },

  -- DROPBAR: Interactive structural breadcrumbs
  {
    'Bekaboo/dropbar.nvim',
    cond = not vim.g.vscode,
    event = { "BufReadPost", "BufNewFile" },
    opts = {}
  },

  -- NVIM-DAP: Debug Adapter Protocol infrastructure & UI panels
  {
    "rcarriga/nvim-dap-ui",
    cond = not vim.g.vscode,
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Debug: Toggle Breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Debug: Start / Continue" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Debug: Step Into" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Debug: Step Over" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Debug: Toggle UI Panels" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()
      dap.listeners.before.attach.dapui_config = function() dapui.open() end
      dap.listeners.before.launch.dapui_config = function() dapui.open() end
      dap.listeners.after.event_terminated.dapui_config = function() dapui.close() end
      dap.listeners.after.event_exited.dapui_config = function() dapui.close() end
    end
  },

}

-- Optional: extend plugin specs with internal/local entries (not tracked in dotfiles)
local local_plugins_path = vim.fn.stdpath("config") .. "/local_plugins.lua"
if vim.fn.filereadable(local_plugins_path) == 1 then
  local ok, extra = pcall(dofile, local_plugins_path)
  if ok and type(extra) == "table" then
    vim.list_extend(plugin_specs, extra)
  end
end

if not vim.g.vscode then
  vim.opt.termguicolors = true
  vim.opt.background = "dark"
end

require("lazy").setup(plugin_specs)

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
    opt.number = true
    opt.relativenumber = true
    opt.mouse = "a"

    -- Automatically reload files when they change on disk
    opt.autoread = true

    -- Force a disk check every time you switch buffers or regain window focus
    vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "CursorHoldI", "FocusGained" }, {
        command = "if mode() != 'c' | checktime | endif",
        pattern = "*",
    })

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
    map('n', '<leader><space>', function() require('fzf-lua').files() end, { desc = "Find Project Files" })
    map('n', '<leader>ff', function() require('fzf-lua').live_grep() end, { desc = "Search Text Globally" })
    map('n', '<leader>fb', function() require('fzf-lua').buffers() end, { desc = "List Active Buffers" })
    map('n', '<leader>fh', function() require('fzf-lua').help_tags() end, { desc = "Search Documentation Help" })

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

-- Optional: load runtime overrides (internal-only config, not tracked in dotfiles)
local local_config_path = vim.fn.stdpath("config") .. "/local_config.lua"
if vim.fn.filereadable(local_config_path) == 1 then
  pcall(dofile, local_config_path)
end
