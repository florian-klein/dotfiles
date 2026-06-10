local options = {
  defaults = {
    vimgrep_arguments = {
      "rg",
      "-L",
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
      "--smart-case",
      "--trim",
      -- Filesystem-level ignores (rg never traverses these — much faster than file_ignore_patterns)
      "--glob", "!.git/",
      "--glob", "!node_modules/",
      "--glob", "!.venv/",
      "--glob", "!venv/",
      "--glob", "!__pycache__/",
      "--glob", "!target/",
      "--glob", "!dist/",
      "--glob", "!build/",
      "--glob", "!.cargo/",
      "--glob", "!*.min.js",
      "--glob", "!*.min.css",
      "--glob", "!package-lock.json",
      "--glob", "!yarn.lock",
      "--glob", "!pnpm-lock.yaml",
      "--glob", "!Cargo.lock",
      "--glob", "!*.map",
    },
    prompt_prefix = "   ",
    selection_caret = "  ",
    entry_prefix = "  ",
    initial_mode = "insert",
    selection_strategy = "reset",
    sorting_strategy = "ascending",
    layout_strategy = "horizontal",
    layout_config = {
      horizontal = {
        prompt_position = "top",
        preview_width = 0.55,
        results_width = 0.8,
      },
      vertical = {
        mirror = false,
      },
      width = 0.87,
      height = 0.80,
      preview_cutoff = 120,
    },
    file_sorter = require("telescope.sorters").get_fuzzy_file,
    file_ignore_patterns = {
      "node_modules/",
      ".cargo/",
      "target/",
      "%.git/",
      "Cargo%.lock",
      "%.venv/",
      "__pycache__/",
      "%.mypy_cache/",
      "%.pytest_cache/",
      "%.ruff_cache/",
      "dist/",
      "build/",
      "%.class$",
      "%.pyc$",
      "%.o$",
      "%.so$",
      "%.dylib$",
      "lazy%-lock%.json",
    },
    generic_sorter = require("telescope.sorters").get_generic_fuzzy_sorter,
    path_display = { "truncate" },
    winblend = 0,
    border = {},
    borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
    color_devicons = true,
    set_env = { ["COLORTERM"] = "truecolor" },
    file_previewer = require("telescope.previewers").vim_buffer_cat.new,
    grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
    qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
    buffer_previewer_maker = require("telescope.previewers").buffer_previewer_maker,
    mappings = {
      n = { ["q"] = require("telescope.actions").close },
    },
    -- Performance: limit results to avoid rendering overhead
    results_title = false,
    dynamic_preview_title = true,
    cache_picker = {
      num_pickers = 5,
      limit_entries = 1000,
    },
  },

  pickers = {
    find_files = {
      -- Use fd instead of rg for file finding — significantly faster
      find_command = {
        "fd", "--type", "f", "--strip-cwd-prefix", "--hidden",
        "--exclude", ".git",
        "--exclude", "node_modules",
        "--exclude", ".venv",
        "--exclude", "venv",
        "--exclude", "__pycache__",
        "--exclude", "target",
        "--exclude", "dist",
        "--exclude", "build",
        "--exclude", ".cargo",
        "--exclude", ".mypy_cache",
        "--exclude", ".pytest_cache",
        "--exclude", ".ruff_cache",
        "--exclude", "*.min.js",
        "--exclude", "*.min.css",
        "--exclude", "*.map",
        "--exclude", "*.pyc",
        "--exclude", "*.class",
        "--exclude", "package-lock.json",
        "--exclude", "yarn.lock",
        "--exclude", "pnpm-lock.yaml",
        "--exclude", "Cargo.lock",
        "--exclude", "lazy-lock.json",
      },
      -- Limit preview for speed
      previewer = false,
    },
    live_grep = {
      -- Only search in files, skip binary
      -- inherits all --glob excludes from vimgrep_arguments above
      additional_args = { "--hidden" },
    },
    buffers = {
      previewer = false,
      sort_lastused = true,
      sort_mru = true,
    },
  },

  extensions_list = { "themes", "terms", "fzf", "live_grep_args", "frecency", "undo", "ui-select" },

  extensions = {
    ["ui-select"] = {
      require("telescope.themes").get_ivy({
        layout_config = { height = 0.35 },
      }),
    },
  },
}

return options
