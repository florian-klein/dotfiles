local M = {}

M.treesitter = {
  ensure_installed = {
    "vim",
    "lua",
    "html",
    "css",
    "javascript",
    "c",
    "markdown",
    "markdown_inline",
    "yaml",
    "python",
    "rust",
    "bash",
    "ocaml",
    "cpp",
    "java",
    "asm", -- Add 'asm' to the list of languages to ensure it's installed
  },
  highlight = {
    enable = true,
    disable = function(lang, buf)
      -- Disable for large files
      local max_filesize = 100 * 1024 -- 100 KB
      local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
      if ok and stats and stats.size > max_filesize then
        return true
      end
    end,
    additional_vim_regex_highlighting = false,
  },
  indent = {
    enable = true,
  },
  textobjects = {
    lsp_interop = {
      enable = true,
      border = 'none',
      floating_preview_opts = {},
      peek_definition_code = {
        ["<S-I>"] = "@function.outer",
        ["<leader>dF"] = "@class.outer",
      },
    },
  },
}

M.mason = {
  ensure_installed = {
    -- lsp servers
    "lua-language-server",
    "css-lsp",
    "html-lsp",
    "typescript-language-server",
    "deno",
    "clangd",
    "texlab",
    "asm-lsp",
    "rust-analyzer",
    "ruff",
    "ty",

    -- formatters
    "stylua",
    "prettier",
    "clang-format",
    "google-java-format",

    -- debuggers
    "codelldb",
  },
}

-- git support in nvimtree
M.nvimtree = {
  git = {
    enable = true,
  },

  renderer = {
    highlight_git = true,
    icons = {
      show = {
        git = true,
      },
    },
  },
}

return M
