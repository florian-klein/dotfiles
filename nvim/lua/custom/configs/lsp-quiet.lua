-- Filters known-benign LSP log noise so the real errors stay visible.
--
-- Background: copilot.lua races its own completion cancellations, which
-- causes Neovim core to log "Cannot find request with id N" (at
-- vim/lsp/client.lua:620) and also forwards Node-side AbortError messages
-- through window/logMessage (at vim/lsp/handlers.lua:562). Both are benign
-- and firing ~100+ times/day each, burying anything actually actionable.
--
-- The fix: wrap `vim.lsp.log.error` so we can drop a short allowlist of
-- patterns before they hit ~/.local/state/nvim/lsp.log. Every other error
-- is logged unchanged.

local M = {}

-- Lua patterns (not regex). Keep these narrow — we only want to drop things
-- we've positively identified as noise.
local NOISE_PATTERNS = {
  "Cannot find request with id %d+ whilst attempting to cancel",
  "%[AsyncCompletionManager%].-AbortError",
  "%[AsyncCompletionManager%].-The operation was aborted",
}

local function is_noise(parts)
  for _, p in ipairs(parts) do
    if type(p) == "string" then
      for _, pat in ipairs(NOISE_PATTERNS) do
        if p:find(pat) then
          return true
        end
      end
    end
  end
  return false
end

function M.setup()
  local log = vim.lsp.log
  local orig_error = log.error
  log.error = function(...)
    if is_noise({ ... }) then
      return true -- pretend we logged; callers only check truthiness
    end
    return orig_error(...)
  end

  -- :LspLogStats — categorize recent errors in the lsp log so you can
  -- re-run this analysis any time.
  vim.api.nvim_create_user_command("LspLogStats", function(opts)
    local days = tonumber(opts.args) or 2
    local path = vim.lsp.log.get_filename()
    local f = io.open(path, "r")
    if not f then
      vim.notify("Could not open " .. path, vim.log.levels.ERROR)
      return
    end

    local cutoff = os.time() - days * 86400
    local buckets = {}
    local total = 0

    for line in f:lines() do
      local ts_y, ts_mo, ts_d, ts_h, ts_mi, ts_s =
        line:match("^%[ERROR%]%[(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)%]")
      if ts_y then
        local t = os.time({
          year = tonumber(ts_y),
          month = tonumber(ts_mo),
          day = tonumber(ts_d),
          hour = tonumber(ts_h),
          min = tonumber(ts_mi),
          sec = tonumber(ts_s),
        })
        if t >= cutoff then
          total = total + 1
          local site = line:match("vim/lsp/[%a_]+%.lua:%d+") or "?"
          local body = line:gsub("^%[ERROR%]%[[^%]]*%]%s*", "")
          body = body:gsub("id %d+", "id N")
          body = body:gsub("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x+", "UUID")
          local key = site .. " | " .. body:sub(1, 100)
          buckets[key] = (buckets[key] or 0) + 1
        end
      end
    end
    f:close()

    local rows = {}
    for k, v in pairs(buckets) do
      table.insert(rows, { count = v, key = k })
    end
    table.sort(rows, function(a, b) return a.count > b.count end)

    local lines = { string.format("LSP errors in last %d days: %d total", days, total), "" }
    for _, r in ipairs(rows) do
      table.insert(lines, string.format("%5d  %s", r.count, r.key))
    end

    vim.cmd("new")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_set_name(buf, "LspLogStats")
  end, {
    nargs = "?",
    desc = "Categorize LSP log errors from the last N days (default 2)",
  })
end

return M
