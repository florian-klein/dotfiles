require "core"

local custom_init_path = vim.api.nvim_get_runtime_file("lua/custom/init.lua", false)[1]
-- Disable python3 provider — all Python tooling uses LSP (ty, ruff)
vim.g.loaded_python3_provider = 0
vim.env.PATH = vim.fn.getcwd() .. "/.venv/bin:" .. vim.env.PATH

if custom_init_path then
  dofile(custom_init_path)
end

-- assert that required ft files were created at ~/.vim/ftdetect/ipynb.vim
-- preint in vim: :echo
-- assert(vim.fn.filereadable(file_type_locations .. "ipynb.vim") == 1, "ftdetect/ipynb.vim not found. Please create a custom filetype for that file.")
-- assert(vim.fn.filereadable(file_type_locations .. "v.vim") == 1, "ftdetect/v.vim not found. Please create a custom filetype for that file.")

require("core.utils").load_mappings()

local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

-- bootstrap lazy.nvim!
if not vim.uv.fs_stat(lazypath) then
  require("core.bootstrap").gen_chadrc_template()
  require("core.bootstrap").lazy(lazypath)
end

dofile(vim.g.base46_cache .. "defaults")
vim.opt.rtp:prepend(lazypath)
require "plugins"
