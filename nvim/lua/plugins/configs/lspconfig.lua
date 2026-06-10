dofile(vim.g.base46_cache .. "lsp")
require "nvchad.lsp"

local M = {}
local utils = require "core.utils"

-- export on_attach & capabilities for custom lspconfigs

M.on_attach = function(client, bufnr)
  client.server_capabilities.documentFormattingProvider = false
  client.server_capabilities.documentRangeFormattingProvider = false

  utils.load_mappings("lspconfig", { buffer = bufnr })

  if client.server_capabilities.signatureHelpProvider then
    require("nvchad.signature").setup(client)
  end

  if not utils.load_config().ui.lsp_semantic_tokens and client.supports_method "textDocument/semanticTokens" then
    -- Use empty table instead of nil to prevent "attempt to index nil" errors
    -- when Neovim's semantic_tokens.lua tries to access semanticTokensProvider.full
    client.server_capabilities.semanticTokensProvider = {}
  end
end

M.capabilities = vim.lsp.protocol.make_client_capabilities()

-- Tell servers NOT to rely on Neovim to watch files for them. Neovim's
-- libuv-based watcher is much slower than what modern LSP servers
-- (rust-analyzer, clangd, pyright/ty, etc.) provide natively. Disabling
-- didChangeWatchedFiles.dynamicRegistration is a well-known speedup.
M.capabilities.workspace = M.capabilities.workspace or {}
M.capabilities.workspace.didChangeWatchedFiles = { dynamicRegistration = false }

-- Merge blink.cmp's completion capabilities (snippet/resolve/documentation
-- support) so servers advertise the right completion shape. pcall-guarded
-- so config still loads cleanly if blink is temporarily removed.
local ok_blink, blink = pcall(require, "blink.cmp")
if ok_blink then
  M.capabilities = blink.get_lsp_capabilities(M.capabilities)
end

return M
