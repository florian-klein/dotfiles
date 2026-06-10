local overrides = require "custom.configs.overrides"

--- custom configs extracted into other files
-- local jupyter = require "custom.configs.jupyter"

--- leap for faster movement
local languages_and_lsps = require "custom.configs.languages_and_lsps"

---@type NvPluginSpec[]
local plugins = {
  -- unpack plugin extracted plugins specs
  -- jupyter,
  languages_and_lsps,
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = false, -- bound manually below so we can close cmp too
          accept_word = "<C-Right>",
          accept_line = "<C-Down>",
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
      panel = { enabled = false },
    },
    config = function(_, opts)
      require("copilot").setup(opts)
      -- ",<Tab>" accepts the Copilot suggestion without colliding with cmp's Tab.
      vim.keymap.set("i", ",<Tab>", function()
        local ok, suggestion = pcall(require, "copilot.suggestion")
        if ok and suggestion.is_visible() then
          local blink_ok, blink = pcall(require, "blink.cmp")
          if blink_ok and blink.is_visible() then blink.hide() end
          suggestion.accept()
        else
          -- No Copilot suggestion pending — insert a literal comma with no remap.
          vim.api.nvim_feedkeys(",", "n", false)
        end
      end, { desc = "Accept Copilot suggestion" })
    end,
  },
  -- Fast formatting via direct CLI calls (bypasses LSP overhead)
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre", "BufNewFile", "BufReadPost" },
    cmd = "ConformInfo",
    keys = {
      { "<leader>fm", function() require("conform").format({ async = true }) end, desc = "Format buffer" },
    },
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_format" },
        rust = { "rustfmt" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        java = { "google-java-format" },
      },
      -- Async format after save — never blocks the editor
      format_after_save = {
        lsp_format = "fallback", -- Use LSP if no CLI formatter configured (e.g. texlab for LaTeX)
        async = true,
      },
      -- Direct formatter overrides for speed
      formatters = {
        ruff_format = {
          -- --preview must come after the "format" subcommand that conform inserts
          append_args = { "--preview" },
        },
        rustfmt = {
          -- Run rustfmt from the nearest dir containing rustfmt.toml /
          -- .rustfmt.toml so per-project style configs are honored.
          cwd = function(_, ctx)
            local found = vim.fs.find(
              { "rustfmt.toml", ".rustfmt.toml", "Cargo.toml" },
              { upward = true, path = vim.fs.dirname(ctx.filename) }
            )[1]
            return found and vim.fs.dirname(found) or nil
          end,
        },
      },
    },
  },
  -- Inline crate version/feature info in Cargo.toml
  {
    "Saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    opts = {},
  },
  -- Pretty inline LSP diagnostics — colored rounded boxes with token-level
  -- highlighting inside error messages (types, paths, quoted strings, etc.).
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "LspAttach",
    priority = 1000, -- needs to run before diagnostics are first rendered
    config = function()
      require("tiny-inline-diagnostic").setup({
        preset = "modern", -- rounded frame + arrow pointer
        options = {
          -- Only render WARN and ERROR inline; suppress HINT/INFO noise
          -- (e.g. rust-analyzer's inactive-code chatter).
          severity = { vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN },
          show_source = { enabled = true, if_many = true },
          multilines = { enabled = true, always_show = false },
          -- On the cursor line, expand long diagnostics to multiple lines;
          -- on other lines, truncate to keep the view clean.
          show_all_diags_on_cursorline = true,
          -- Respect update_in_insert = false: hide while typing.
          enable_on_insert = false,
          use_icons_from_diagnostic = true,
          overflow = { mode = "wrap" },
          blend = { factor = 0.22 }, -- subtle background tint
        },
      })
      -- The plugin replaces Neovim's virtual_text renderer; turn the core
      -- one off to avoid double-rendering.
      vim.diagnostic.config({ virtual_text = false })
    end,
  },
  -- Snippet engine (was nested inside nvim-cmp; now standalone for blink.cmp)
  {
    "L3MON4D3/LuaSnip",
    lazy = true,
    dependencies = "rafamadriz/friendly-snippets",
    opts = { history = true, updateevents = "TextChanged,TextChangedI" },
    config = function(_, opts)
      require("plugins.configs.others").luasnip(opts)
    end,
  },
  -- Auto-pair brackets/quotes (was nested in nvim-cmp; cmp integration removed)
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      fast_wrap = {},
      disable_filetype = { "TelescopePrompt", "vim" },
    },
  },
  -- Blink.cmp — Rust-core completion engine, replaces nvim-cmp
  {
    "saghen/blink.cmp",
    -- Off the startup path: lazy.nvim auto-loads this when lspconfig's
    -- pcall(require, "blink.cmp") capability merge runs at LSP setup, and
    -- InsertEnter/CmdlineEnter cover non-LSP buffers.
    event = { "InsertEnter", "CmdlineEnter" },
    version = "*", -- use prebuilt binary from latest release tag
    dependencies = { "L3MON4D3/LuaSnip", "rafamadriz/friendly-snippets" },
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        preset = "default", -- C-n/C-p/C-y/C-e/C-Space, plus the overrides below
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
        ["<C-d>"] = { "scroll_documentation_down", "fallback" },
        ["<C-f>"] = { "scroll_documentation_up", "fallback" },
      },
      snippets = { preset = "luasnip" },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      completion = {
        -- Auto-show docs next to the menu after a short delay
        documentation = { auto_show = true, auto_show_delay_ms = 200 },
        -- Show ghost text for the selected item; helps feel "instant"
        ghost_text = { enabled = false },
        menu = { border = "rounded" },
      },
      signature = { enabled = true, window = { border = "rounded" } },
      -- Use Rust fuzzy matcher (the whole point of blink)
      fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    opts_extend = { "sources.default" },
  },
  -- Telescope extensions
  {
    "debugloop/telescope-undo.nvim",
    lazy = true,
  },
  {
    "nvim-telescope/telescope-ui-select.nvim",
    lazy = true,
  },
  -- Auto-install all mason tools (so remote hosts just work). VeryLazy:
  -- the registry check runs right after the UI renders instead of before.
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    event = "VeryLazy",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = overrides.mason.ensure_installed,
      auto_update = false,
      run_on_start = true,
    },
  },
  {
    "dmtrKovalenko/fff.nvim",
    build = function()
      require("fff.download").download_or_build_binary()
    end,
    opts = {},
    -- VeryLazy keeps the background file index warming early without
    -- blocking startup; the keys load it on demand too.
    event = "VeryLazy",
    keys = {
      { "<leader>ff", function() require("fff").find_files() end, desc = "Find files (fff)" },
      { "<leader>fw", function() require("fff").live_grep() end, desc = "Live grep (fff)" },
    },
  },
  -- Claude Code integration: official ACP-based plugin from Coder.
  -- Uses snacks.nvim's terminal for the chat split.
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = {
      "ClaudeCode",
      "ClaudeCodeFocus",
      "ClaudeCodeSend",
      "ClaudeCodeAdd",
      "ClaudeCodeSelectModel",
      "ClaudeCodeDiffAccept",
      "ClaudeCodeDiffDeny",
    },
    -- <leader>a is already AerialToggle, so prefix Claude maps under <leader>k.
    keys = {
      { "<leader>kk", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
      { "<leader>kf", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
      { "<leader>kr", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
      { "<leader>kC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
      { "<leader>km", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
      { "<leader>kb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer to Claude" },
      { "<leader>ks", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
      { "<leader>ka", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Claude diff" },
      { "<leader>kd", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny Claude diff" },
    },
    opts = {
      -- Preserve the CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 flag the user sets via shell alias.
      terminal_cmd = "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude",
    },
  },
  -- snacks.nvim — required by claudecode.nvim for terminal split.
  -- Loaded lazily; claudecode pulls it in via dependencies.
  {
    "folke/snacks.nvim",
    lazy = true,
    opts = {},
  },
  {
    "mikesmithgh/kitty-scrollback.nvim",
    enabled = true,
    lazy = true,
    cmd = { "KittyScrollbackGenerateKittens", "KittyScrollbackCheckHealth" },
    event = { "User KittyScrollbackLaunch" },
    config = function()
      require("kitty-scrollback").setup()
    end,
  },
}

return plugins
