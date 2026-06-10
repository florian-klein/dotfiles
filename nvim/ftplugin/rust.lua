-- Rust-specific buffer-local overrides.
--
-- Why this file exists: nvchad's `load_mappings("lspconfig", {buffer=bufnr})`
-- runs inside vim.schedule() from the LspAttach autocmd and occasionally
-- loses the race on Rust buffers (likely because rustaceanvim attaches
-- rust-analyzer via its own code path rather than lspconfig's enable flow).
-- When it loses, `gd` falls through to Vim's builtin word-search behavior,
-- which just highlights the cword. Installing `gd` from an ftplugin
-- guarantees the buffer-local mapping exists before the user touches the
-- buffer, regardless of LSP attach timing.

local bufnr = vim.api.nvim_get_current_buf()
local opts = { buffer = bufnr, silent = true }

vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end,
  vim.tbl_extend("force", opts, { desc = "LSP definition" }))
vim.keymap.set("n", "gD", function() vim.lsp.buf.declaration() end,
  vim.tbl_extend("force", opts, { desc = "LSP declaration" }))
vim.keymap.set("n", "gi", function() vim.lsp.buf.implementation() end,
  vim.tbl_extend("force", opts, { desc = "LSP implementation" }))
vim.keymap.set("n", "gr", function() vim.lsp.buf.references() end,
  vim.tbl_extend("force", opts, { desc = "LSP references" }))

-- rustaceanvim-provided navigation/inspection commands.
vim.keymap.set("n", "<leader>rm", function() vim.cmd.RustLsp("expandMacro") end,
  vim.tbl_extend("force", opts, { desc = "Rust: expand macro at cursor" }))
vim.keymap.set("n", "<leader>rc", function() vim.cmd.RustLsp("openCargo") end,
  vim.tbl_extend("force", opts, { desc = "Rust: open Cargo.toml" }))
vim.keymap.set("n", "<leader>rp", function() vim.cmd.RustLsp("parentModule") end,
  vim.tbl_extend("force", opts, { desc = "Rust: jump to parent module" }))
