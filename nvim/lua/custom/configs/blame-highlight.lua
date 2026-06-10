-- Custom git blame line highlighting
-- Highlights actual code lines with background colors based on commit hash

local M = {}

local ns_id = vim.api.nvim_create_namespace("blame_highlight")
local enabled_bufs = {}

-- Muted, calm color palette for dark backgrounds
-- Colors are designed to be distinguishable but not distracting
-- Inspired by muted dark mode pastels
local COLOR_PALETTE = {
  "#2d3a3a", -- Muted teal
  "#3a2d3a", -- Muted plum
  "#2d3a2d", -- Muted sage
  "#3a3a2d", -- Muted olive
  "#2d2d3a", -- Muted indigo
  "#3a2d2d", -- Muted rose
  "#2d383a", -- Muted cyan
  "#38332d", -- Muted amber
  "#352d3a", -- Muted violet
  "#2d3a35", -- Muted mint
  "#3a352d", -- Muted sienna
  "#2d353a", -- Muted steel
}

-- Hash a commit SHA to get a deterministic color index
local function hash_to_index(hash)
  if not hash or hash == "" then
    return 1
  end

  -- Use first 8 chars of hash to compute a number
  local num = 0
  for i = 1, math.min(8, #hash) do
    local byte = string.byte(hash, i)
    num = (num * 31 + byte) % 1000000
  end

  return (num % #COLOR_PALETTE) + 1
end

-- Get color for a commit, ensuring it differs from previous commit's color
local function get_commit_color(hash, prev_color_index)
  local index = hash_to_index(hash)

  -- If same as previous, shift to next color
  if prev_color_index and index == prev_color_index then
    index = (index % #COLOR_PALETTE) + 1
  end

  return COLOR_PALETTE[index], index
end

-- Apply highlights to buffer
local function apply_highlights(bufnr, blame_data)
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local hl_cache = {}
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local applied = 0

  -- Sort lines to process in order (for neighbor detection)
  local sorted_lines = {}
  for lnum, _ in pairs(blame_data) do
    table.insert(sorted_lines, lnum)
  end
  table.sort(sorted_lines)

  -- Track previous line's color to ensure neighbors differ
  local prev_color_index = nil
  local prev_hash = nil

  for _, lnum in ipairs(sorted_lines) do
    local data = blame_data[lnum]

    -- Skip if line doesn't exist in buffer
    if lnum > line_count or lnum < 1 then
      goto continue
    end

    -- Get color based on commit hash, avoiding same color as previous line
    local color, color_index
    if data.hash == prev_hash then
      -- Same commit as previous line, use same color
      color = COLOR_PALETTE[prev_color_index]
      color_index = prev_color_index
    else
      -- Different commit, get new color (avoiding neighbor collision)
      color, color_index = get_commit_color(data.hash, prev_color_index)
    end

    local hl_name = "BlameCommit_" .. color:gsub("#", "")

    if not hl_cache[color] then
      -- Force create highlight with explicit background
      vim.api.nvim_set_hl(0, hl_name, {
        bg = color,
        default = false,
      })
      hl_cache[color] = true
    end

    -- Get the line content to determine end column
    local line_content = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""

    -- Apply highlight using extmark with hl_eol for full line coverage
    local ok, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, lnum - 1, 0, {
      end_row = lnum - 1,
      end_col = #line_content,
      hl_group = hl_name,
      hl_eol = true,
      priority = 100,
    })

    if ok then
      applied = applied + 1
    else
      vim.notify(string.format("Extmark error at line %d: %s", lnum, tostring(err)), vim.log.levels.WARN)
    end

    prev_color_index = color_index
    prev_hash = data.hash

    ::continue::
  end

  return applied
end

-- Parse git blame porcelain output
local function parse_blame_output(data)
  local blame_data = {}
  local timestamps = {}
  local commit_timestamps = {} -- Cache: hash -> timestamp

  local current_hash = nil
  local current_final_line = nil

  for _, line in ipairs(data) do
    -- Skip empty lines
    if not line or line == "" then
      goto continue
    end

    -- Commit line pattern: 40 hex chars + orig_line + final_line [+ count]
    -- Format: "hash orig_line final_line [count]"
    local hash, orig, final = line:match("^(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)%s+(%d+)%s+(%d+)")
    if hash then
      current_hash = hash
      current_final_line = tonumber(final)

      -- If we already know timestamp for this commit, record immediately
      if commit_timestamps[hash] then
        blame_data[current_final_line] = {
          hash = hash,
          timestamp = commit_timestamps[hash],
        }
      end
      goto continue
    end

    -- Author-time line
    local ts = line:match("^author%-time%s+(%d+)")
    if ts and current_hash then
      local timestamp = tonumber(ts)

      -- Only record if we haven't seen this commit before
      if not commit_timestamps[current_hash] then
        commit_timestamps[current_hash] = timestamp
        table.insert(timestamps, timestamp)
      end

      -- Now we can record the current line (first occurrence of this commit)
      if current_final_line and not blame_data[current_final_line] then
        blame_data[current_final_line] = {
          hash = current_hash,
          timestamp = timestamp,
        }
      end
      goto continue
    end

    ::continue::
  end

  return blame_data, timestamps
end

-- Get blame and highlight buffer
function M.highlight_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if filepath == "" then
    vim.notify("Buffer has no file", vim.log.levels.WARN)
    return
  end

  -- Get the directory of the file for git context
  local filedir = vim.fn.fnamemodify(filepath, ":h")

  -- Run git blame with porcelain format from the file's directory
  local cmd = string.format(
    "cd %s && git blame --date=unix -p -- %s 2>/dev/null",
    vim.fn.shellescape(filedir),
    vim.fn.shellescape(vim.fn.fnamemodify(filepath, ":t"))
  )

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data or #data == 0 then
        vim.schedule(function()
          vim.notify("No git blame output", vim.log.levels.WARN)
        end)
        return
      end

      local blame_data, timestamps = parse_blame_output(data)
      local line_count = vim.tbl_count(blame_data)

      if line_count == 0 or #timestamps == 0 then
        vim.schedule(function()
          vim.notify("No blame data found (file may not be tracked)", vim.log.levels.WARN)
        end)
        return
      end

      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          local applied = apply_highlights(bufnr, blame_data)
          enabled_bufs[bufnr] = true
          vim.notify(string.format("Blame: %d/%d lines (%d commits)", applied, line_count, #timestamps), vim.log.levels.INFO)
        end
      end)
    end,
    on_stderr = function(_, data)
      if data and data[1] and data[1] ~= "" then
        vim.schedule(function()
          vim.notify("Git blame error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
        end)
      end
    end,
  })
end

-- Debug function to test parsing
function M.debug(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  if filepath == "" then
    vim.notify("Buffer has no file", vim.log.levels.WARN)
    return
  end

  local filedir = vim.fn.fnamemodify(filepath, ":h")
  local filename = vim.fn.fnamemodify(filepath, ":t")

  local cmd = string.format(
    "cd %s && git blame --date=unix -p -- %s",
    vim.fn.shellescape(filedir),
    vim.fn.shellescape(filename)
  )

  vim.notify("Running: " .. cmd, vim.log.levels.INFO)

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data then
        vim.schedule(function()
          vim.notify("No data received", vim.log.levels.ERROR)
        end)
        return
      end

      local blame_data, timestamps = parse_blame_output(data)
      local line_count = vim.tbl_count(blame_data)
      local buf_lines = vim.api.nvim_buf_line_count(bufnr)

      vim.schedule(function()
        vim.notify(string.format(
          "Debug: received %d lines, parsed %d blame entries, buffer has %d lines, %d unique commits",
          #data, line_count, buf_lines, #timestamps
        ), vim.log.levels.INFO)

        -- Show first 5 parsed entries
        local sorted = {}
        for lnum, _ in pairs(blame_data) do
          table.insert(sorted, lnum)
        end
        table.sort(sorted)

        local preview = {}
        for i = 1, math.min(5, #sorted) do
          local lnum = sorted[i]
          local d = blame_data[lnum]
          table.insert(preview, string.format("L%d:%s", lnum, d.hash:sub(1, 7)))
        end
        vim.notify("Sample: " .. table.concat(preview, ", "), vim.log.levels.INFO)
      end)
    end,
    on_stderr = function(_, data)
      if data and data[1] ~= "" then
        vim.schedule(function()
          vim.notify("stderr: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
        end)
      end
    end,
  })
end

-- Clear highlights from buffer
function M.clear_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  enabled_bufs[bufnr] = nil
end

-- Toggle highlights
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if enabled_bufs[bufnr] then
    M.clear_buffer(bufnr)
    vim.notify("Blame highlighting disabled", vim.log.levels.INFO)
  else
    M.highlight_buffer(bufnr)
  end
end

-- Setup commands
vim.api.nvim_create_user_command("BlameHighlightToggle", function()
  M.toggle()
end, { desc = "Toggle git blame line highlighting" })

vim.api.nvim_create_user_command("BlameHighlightDebug", function()
  M.debug()
end, { desc = "Debug git blame parsing" })

return M
