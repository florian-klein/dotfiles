--@type MappingsTable
local M = {}

M.ignore = {}

-- Custom code actions menu: LSP actions + tracing/rename, numbered inputlist UI.
local function show_code_actions_menu()
  local bufnr = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  local actions = {}

  local function add_static_actions()
    table.insert(actions, {
      label = " Rename Symbol",
      action = function() vim.lsp.buf.rename() end,
    })
    table.insert(actions, { label = " Incoming Calls (trace callers)", action = function() vim.cmd("Lspsaga incoming_calls") end })
    table.insert(actions, { label = " Outgoing Calls (trace callees)", action = function() vim.cmd("Lspsaga outgoing_calls") end })
    table.insert(actions, { label = " Find All References", action = function() vim.cmd("Lspsaga finder") end })
    table.insert(actions, { label = " Peek Definition", action = function() vim.cmd("Lspsaga peek_definition") end })
    table.insert(actions, { label = " Peek Type Definition", action = function() vim.cmd("Lspsaga peek_type_definition") end })

    if vim.bo.filetype == "rust" then
      table.insert(actions, {
        label = " Focus Mode (data flow)",
        action = function()
          vim.notify("Flowistry: Analyzing data flow...", vim.log.levels.INFO)
          vim.cmd("Flowistry focus toggle")
        end,
      })
      table.insert(actions, {
        label = " Mark for Tracing",
        action = function()
          vim.cmd("Flowistry mark set")
          vim.notify("Flowistry: Mark set at cursor", vim.log.levels.INFO)
        end,
      })
      table.insert(actions, {
        label = " Remove Mark",
        action = function()
          vim.cmd("Flowistry mark remove")
          vim.notify("Flowistry: Mark removed", vim.log.levels.INFO)
        end,
      })
    end
  end

  -- Numbered bottom-of-screen picker. Much simpler than vim.ui.select and gives
  -- the "press N to run X" UI the user wants.
  local function show()
    if #actions == 0 then
      vim.notify("No code actions available", vim.log.levels.INFO)
      return
    end
    local prompt = { "Code Actions:" }
    for i, a in ipairs(actions) do
      table.insert(prompt, string.format("%d. %s", i, a.label))
    end
    vim.schedule(function()
      local choice = vim.fn.inputlist(prompt)
      if choice and choice > 0 and choice <= #actions then
        actions[choice].action()
      end
    end)
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/codeAction" })

  if #clients == 0 then
    add_static_actions()
    show()
    return
  end

  local remaining = #clients
  for _, client in ipairs(clients) do
    local params = vim.lsp.util.make_range_params(win, client.offset_encoding)

    -- Pass through the raw LSP diagnostics that the server attached, same as
    -- vim.lsp.buf.code_action. Hand-rolled conversions drop server-specific
    -- fields like `data` that some actions (rust-analyzer, tsserver) depend on.
    local ns_push = vim.lsp.diagnostic.get_namespace(client.id, false)
    local ns_pull = vim.lsp.diagnostic.get_namespace(client.id, true)
    local lnum = vim.api.nvim_win_get_cursor(win)[1] - 1
    local diags = {}
    vim.list_extend(diags, vim.diagnostic.get(bufnr, { namespace = ns_pull, lnum = lnum }))
    vim.list_extend(diags, vim.diagnostic.get(bufnr, { namespace = ns_push, lnum = lnum }))
    params.context = {
      triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
      diagnostics = vim.tbl_map(function(d)
        return (d.user_data or {}).lsp or {}
      end, diags),
    }

    local function handle_response(err, result)
      if err then
        vim.schedule(function()
          vim.notify(
            string.format("[%s] code action error: %s", client.name, err.message or vim.inspect(err)),
            vim.log.levels.WARN
          )
        end)
      end
      if result then
        for _, action in ipairs(result) do
          local captured_client = client
          local captured_action = action
          table.insert(actions, {
            label = action.title,
            action = function()
              local function apply(resolved)
                if resolved.edit then
                  vim.lsp.util.apply_workspace_edit(resolved.edit, captured_client.offset_encoding)
                end
                if resolved.command then
                  local cmd = type(resolved.command) == "table" and resolved.command or resolved
                  captured_client:request("workspace/executeCommand", cmd, function() end, bufnr)
                end
              end
              local supports_resolve = vim.tbl_get(
                captured_client.server_capabilities or {},
                "codeActionProvider",
                "resolveProvider"
              )
              if not captured_action.edit and supports_resolve then
                captured_client:request("codeAction/resolve", captured_action, function(resolve_err, resolved)
                  apply((not resolve_err and resolved) or captured_action)
                end, bufnr)
              else
                apply(captured_action)
              end
            end,
          })
        end
      end
      remaining = remaining - 1
      if remaining == 0 then
        add_static_actions()
        show()
      end
    end

    local ok = client:request("textDocument/codeAction", params, handle_response, bufnr)
    if not ok then
      remaining = remaining - 1
      if remaining == 0 then
        add_static_actions()
        show()
      end
    end
  end
end

M.general = {
  n = {
    [";"] = { ":", "enter command mode", opts = { nowait = true } },
    ["s"] = { ":vs<CR>", "split" },
    ["x"] = { ":wq<CR>", "quit" },
    ["<C-s>"] = { ":w<CR>", "save file" },
    ["<leader>gb"] = { "<cmd> Telescope git_branches <CR>", "Git branches" },
    -- <leader>fw remapped to fff.nvim in plugins.lua
    -- Undo history browser
    ["<leader>fu"] = { "<cmd>Telescope undo<CR>", "Undo history" },
    -- Frecency - frequency+recency based file finding
    ["<leader>fp"] = { "<cmd>Telescope frecency<CR>", "Frecency files" },
    ["<leader>xx"] = { "<cmd>Trouble diagnostics toggle focus=true<cr>", "Trouble" },
    ["<leader>qf"] = { "<cmd>Trouble qflist toggle<cr>", "View Quickfix Options" },
    ["<leader>xd"] = { "<cmd>lua require('trouble').toggle('document_diagnostics')<CR>", "Document Diagnostics" },
    ["<leader>xq"] = { "<cmd>lua require('trouble').toggle('quickfix')<CR>", "Quickfix" },
    ["<leader>xl"] = { "<cmd>lua require('trouble').toggle('loclist')<CR>", "Loclist" },
    ["<leader>a"] = { "<cmd>AerialToggle!<CR>" },
    ["<C-m>"] = { "<cmd>AerialPrev<CR>" },
    ["<C-n>"] = { ":cnext<CR>", "Next quickfix item" },
    ["<C-p>"] = { ":cprev<CR>", "Previous quickfix item" },
    ["<leader>cf"] = { ":cfirst<CR>", "First quickfix item" },
    ["<leader>cl"] = { ":clast<CR>", "Last quickfix item" },
    ["<C-M>"] = { "<cmd>AerialNext<CR>" },
    ["gR"] = { "<cmd>lua require('trouble').toggle('lsp_references')<CR>", "LSP References" },
    -- Git blame code highlighting (actual line backgrounds by commit age)
    ["<leader>bh"] = { function() require("custom.configs.blame-highlight").toggle() end, "Toggle blame line highlighting" },
    -- Code actions menu (includes LSP actions + call hierarchy + finder)
    ["<leader>ca"] = { function() show_code_actions_menu() end, "Code actions menu" },
    -- Toggle LSP inlay hints (any filetype with a server that provides them)
    ["<leader>ih"] = {
      function()
        local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
        vim.lsp.inlay_hint.enable(not enabled, { bufnr = 0 })
      end,
      "Toggle inlay hints",
    },
    -- Rust-specific: rerun last debug (main debug keybinding is in nvim-dap-ui config)
    ["<leader>dL"] = {
      function()
        if vim.bo.filetype == "rust" then
          -- Rerun last debug session
          vim.cmd.RustLsp({ "debuggables", bang = true })
        else
          vim.notify("Not a Rust file", vim.log.levels.WARN)
        end
      end,
      "Rerun last Rust debug"
    },
    ["<leader>rt"] = {
      function()
        if vim.bo.filetype == "rust" then
          -- Run tests (no debug, uses cargo test/nextest)
          vim.cmd.RustLsp("testables")
        else
          vim.notify("Not a Rust file", vim.log.levels.WARN)
        end
      end,
      "Run Rust test"
    },
    ["<leader>rr"] = {
      function()
        if vim.bo.filetype == "rust" then
          -- Run any target (no debug)
          vim.cmd.RustLsp("runnables")
        else
          vim.notify("Not a Rust file", vim.log.levels.WARN)
        end
      end,
      "Run Rust target"
    },
    -- ["f"] = { "<cmd>lua require('leap').leap({target_windows = {vim.fn.win_getid()}})<CR>", "Leap forward" },
    -- ["F"] = { "<cmd>lua require('leap').leap({target_windows = {vim.fn.win_getid()}, backward = true})<CR>", "Leap backward" },

    -- ─── LaTeX Preview (Skim) ──────────────────────────────────────────────────
    ["<leader>lp"] = {
      function()
        local pdf = vim.fn.expand("%:p:r") .. ".pdf"
        if vim.fn.filereadable(pdf) == 1 then
          vim.fn.jobstart({ "open", "-a", "Skim", pdf })
        else
          vim.notify("PDF not found: " .. pdf, vim.log.levels.WARN)
        end
      end,
      "LaTeX: Preview PDF (Skim)"
    },
    ["<leader>lc"] = {
      function()
        local file = vim.fn.expand("%")
        vim.notify("Compiling LaTeX...", vim.log.levels.INFO)
        vim.fn.jobstart({ "latexmk", "-pdf", "-interaction=nonstopmode", file }, {
          on_exit = function(_, code)
            if code == 0 then
              vim.notify("LaTeX compiled successfully", vim.log.levels.INFO)
            else
              vim.notify("LaTeX compilation failed", vim.log.levels.ERROR)
            end
          end,
        })
      end,
      "LaTeX: Compile PDF"
    },
    ["<leader>lw"] = {
      function()
        local file = vim.fn.expand("%")
        vim.notify("Starting latexmk watch mode...", vim.log.levels.INFO)
        vim.fn.jobstart({ "latexmk", "-pdf", "-pvc", "-interaction=nonstopmode", file }, {
          detach = true,
        })
      end,
      "LaTeX: Start watch mode (continuous compile)"
    },
    ["<leader>lx"] = {
      function()
        local dir = vim.fn.expand("%:p:h")
        vim.notify("Cleaning LaTeX auxiliary files...", vim.log.levels.INFO)
        vim.fn.jobstart({ "latexmk", "-c" }, {
          cwd = dir,
          on_exit = function(_, code)
            if code == 0 then
              vim.notify("LaTeX aux files cleaned", vim.log.levels.INFO)
            end
          end,
        })
      end,
      "LaTeX: Clean auxiliary files"
    },
  },
  v = {
    ["<TAB>"] = { ">gv", "shift selected text right" },
    ["<S-TAB>"] = { "<gv", "shift selected text left" },
  },
}

return M
