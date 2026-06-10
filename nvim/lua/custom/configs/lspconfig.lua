local base_on_attach = require("plugins.configs.lspconfig").on_attach
local capabilities = require("plugins.configs.lspconfig").capabilities

-- Handle workspace/diagnostic/refresh properly (don't reset, let LSP push new diagnostics)
vim.lsp.handlers["workspace/diagnostic/refresh"] = function(_, result, ctx)
  return vim.NIL
end

-- NvChad's nvchad/lsp.lua (required above via plugins.configs.lspconfig) sets
-- virtual_text = { prefix = "" }. Override it here, AFTER nvchad runs, because
-- tiny-inline-diagnostic.nvim replaces Neovim's virtual_text renderer.
vim.diagnostic.config({ virtual_text = false })

-- Disable rust-analyzer auto-start (handled by rustaceanvim)
vim.g.rustaceanvim_standalone = false
pcall(function()
  vim.lsp.config("rust_analyzer", { autostart = false })
end)

-- Neutralize nvim-lspconfig's bundled lsp/copilot.lua. We use
-- zbirenbaum/copilot.lua (its own LSP client, not vim.lsp.enable-managed),
-- but lspconfig's config gets enabled somewhere downstream and floods lsp.log
-- with "copilot-language-server is not executable" on every buffer. Empty
-- filetypes makes can_start() short-circuit before the cmd validation runs.
pcall(vim.lsp.config, "copilot", { filetypes = {} })

-- Main LspAttach autocmd (formatting handled by conform.nvim, not here)
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp_attach_setup", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local bufnr = args.buf
    if client == nil then
      return
    end

    -- Disable ruff's hover in favor of ty's hover for Python
    if client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end

    -- Disable semantic tokens for servers that don't properly provide the legend
    if client.name == "rust_analyzer" then
      client.server_capabilities.semanticTokensProvider = nil
    end

    -- Call the base on_attach for keymappings (gd, gr, K, etc.)
    base_on_attach(client, bufnr)

    -- Disable LSP formatting — conform.nvim handles all formatting directly
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
  desc = "LSP: Setup keymappings and capabilities",
})

-- Set Rust toolchain to nightly
vim.env.RUSTUP_TOOLCHAIN = "nightly"

local servers = {
  "html",
  "cssls",
  "clangd",
  "texlab",
  "asm_lsp",
}

-- LSP-specific command overrides
local lsp_cmd = {
  clangd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=iwyu",
    "--pch-storage=memory",
    "-j=4",
    "--malloc-trim",
  },
}

-- Loop through servers and set configurations
for _, lsp in ipairs(servers) do
  local setup_config = {
    capabilities = capabilities,
  }

  if lsp_cmd[lsp] then
    setup_config.cmd = lsp_cmd[lsp]
  end

  vim.lsp.config(lsp, setup_config)
  vim.lsp.enable(lsp)
end

-- Function to dynamically update Rust Analyzer features
function UpdateRustAnalyzerFeatures(features, no_default_features)
  local params = {
    settings = {
      ["rust-analyzer"] = {
        cargo = {
          loadOutDirsFromCheck = true,
          features = features or {},
          noDefaultFeatures = no_default_features or false,
        },
      },
    },
  }
  local clients = vim.lsp.get_clients()
  for _, client in ipairs(clients) do
    if client.name == "rust_analyzer" then
      local status_ok, err = pcall(client.notify, client, "workspace/didChangeConfiguration", params)
      if not status_ok then
        vim.notify("Failed to update Rust Analyzer configuration: " .. err, vim.log.levels.ERROR)
      else
        vim.notify("Rust Analyzer features updated successfully.", vim.log.levels.INFO)
      end
    end
  end
end

-- Command to switch Rust Analyzer features dynamically
vim.api.nvim_create_user_command("RustSwitchFeatures", function(args)
  if args.args == "" then
    vim.notify("No features provided. Please specify features separated by commas.", vim.log.levels.ERROR)
    return
  end
  local features = vim.split(args.args, ",")
  UpdateRustAnalyzerFeatures(features)
end, {
  nargs = 1,
  desc = "Switch rust-analyzer features dynamically",
})

-- Command to disable all non-default Rust Analyzer features
vim.api.nvim_create_user_command("RustDisableNonDefaultFeatures", function()
  UpdateRustAnalyzerFeatures({}, true)
end, {
  nargs = 0,
  desc = "Disable all non-default features in rust-analyzer",
})

-- Python LSP root_dir function: falls back to file's directory (never home)
local python_root_markers = { "ty.toml", "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" }

local function python_root_dir(bufnr, on_dir)
  local root = vim.fs.root(bufnr, python_root_markers)
  if root and root ~= vim.env.HOME then
    on_dir(root)
  else
    local fname = vim.api.nvim_buf_get_name(bufnr)
    on_dir(vim.fn.fnamemodify(fname, ":p:h"))
  end
end

-- ty - Python type checker
vim.lsp.config("ty", {
  capabilities = capabilities,
  root_dir = python_root_dir,
  init_options = {
    logLevel = "warn",
  },
  settings = {
    ty = {
      diagnosticMode = "openFilesOnly",
      completions = {
        autoImport = true,
      },
      inlayHints = {
        variableTypes = true,
        callArgumentNames = true,
      },
    },
  },
})
vim.lsp.enable("ty")

-- ruff - Python linter + formatter
vim.lsp.config("ruff", {
  capabilities = capabilities,
  root_dir = python_root_dir,
  init_options = {
    settings = {
      logLevel = "warn",
      lint = { enable = true },
      format = { preview = true },
      exclude = {
        "**/miniconda3/**",
        "**/.cache/**",
        "**/site-packages/**",
        "**/__pycache__/**",
        "**/.venv/**",
        "**/venv/**",
      },
    },
  },
})
vim.lsp.enable("ruff")
