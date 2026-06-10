-- Benchmark: fff.nvim vs Telescope (fd/rg) for file search and grep
-- Usage: :luafile lua/benchmark_fff_vs_telescope.lua
--    or: nvim --headless -c "luafile lua/benchmark_fff_vs_telescope.lua" -c "qa!"

local ITERATIONS = 20
local FILE_QUERY = "init"
local GREP_QUERY = "require"

local function hrtime_ms()
  return vim.loop.hrtime() / 1e6
end

local function stats(times)
  table.sort(times)
  local sum = 0
  for _, t in ipairs(times) do sum = sum + t end
  return {
    min = times[1],
    max = times[#times],
    mean = sum / #times,
    median = times[math.ceil(#times / 2)],
    p95 = times[math.ceil(#times * 0.95)],
  }
end

local function fmt(s)
  return string.format("  min=%.2fms  median=%.2fms  mean=%.2fms  p95=%.2fms  max=%.2fms", s.min, s.median, s.mean, s.p95, s.max)
end

local results = {}

-- ── fff.nvim file search ──────────────────────────────────────────────
do
  local ok, fff_picker = pcall(require, "fff.file_picker")
  if ok then
    -- ensure index is built
    fff_picker.setup()
    fff_picker.scan_files()
    vim.wait(500, function() return false end) -- let async scan finish

    local times = {}
    for i = 1, ITERATIONS do
      local t0 = hrtime_ms()
      local res = fff_picker.search_files(FILE_QUERY, nil, 50)
      local elapsed = hrtime_ms() - t0
      times[i] = elapsed
    end
    results.fff_files = { stats = stats(times), count = #(fff_picker.search_files(FILE_QUERY, nil, 50) or {}) }
  else
    results.fff_files = { error = "fff.nvim not loaded" }
  end
end

-- ── Telescope / fd file search ────────────────────────────────────────
do
  local times = {}
  for i = 1, ITERATIONS do
    local t0 = hrtime_ms()
    local out = vim.fn.systemlist({ "fd", "--type", "f", "--max-results", "50", FILE_QUERY })
    local elapsed = hrtime_ms() - t0
    times[i] = elapsed
    if i == 1 then results.fd_count = #out end
  end
  results.fd_files = { stats = stats(times), count = results.fd_count }
end

-- ── fff.nvim grep ─────────────────────────────────────────────────────
do
  local ok, fff_grep = pcall(require, "fff.grep")
  if ok then
    local times = {}
    for i = 1, ITERATIONS do
      local t0 = hrtime_ms()
      local res = fff_grep.search(GREP_QUERY, 0, 50)
      local elapsed = hrtime_ms() - t0
      times[i] = elapsed
    end
    local last = fff_grep.search(GREP_QUERY, 0, 50)
    results.fff_grep = { stats = stats(times), count = last and last.total_matched or 0 }
  else
    results.fff_grep = { error = "fff.nvim grep not loaded" }
  end
end

-- ── Telescope / rg grep ──────────────────────────────────────────────
do
  local times = {}
  for i = 1, ITERATIONS do
    local t0 = hrtime_ms()
    local out = vim.fn.systemlist({ "rg", "--max-count", "50", "--no-heading", "--line-number", GREP_QUERY })
    local elapsed = hrtime_ms() - t0
    times[i] = elapsed
    if i == 1 then results.rg_count = #out end
  end
  results.rg_grep = { stats = stats(times), count = results.rg_count }
end

-- ── Print results ─────────────────────────────────────────────────────
local sep = string.rep("─", 70)

print("")
print(sep)
print(string.format("  Benchmark: %d iterations | file query=%q | grep query=%q", ITERATIONS, FILE_QUERY, GREP_QUERY))
print(string.format("  cwd: %s", vim.fn.getcwd()))
print(sep)
print("")

print("FILE SEARCH (query: " .. FILE_QUERY .. ")")
print("")
if results.fff_files.error then
  print("  fff.nvim:  " .. results.fff_files.error)
else
  print("  fff.nvim (" .. (results.fff_files.count or "?") .. " results):")
  print(fmt(results.fff_files.stats))
end
print("")
print("  fd → Telescope (" .. (results.fd_files.count or "?") .. " results):")
print(fmt(results.fd_files.stats))

print("")
print(sep)
print("")

print("GREP (query: " .. GREP_QUERY .. ")")
print("")
if results.fff_grep.error then
  print("  fff.nvim:  " .. results.fff_grep.error)
else
  print("  fff.nvim (" .. (results.fff_grep.count or "?") .. " matches):")
  print(fmt(results.fff_grep.stats))
end
print("")
print("  rg → Telescope (" .. (results.rg_grep.count or "?") .. " results):")
print(fmt(results.rg_grep.stats))

print("")
print(sep)

-- Speedup summary
if results.fff_files.stats and results.fd_files.stats then
  local ratio = results.fd_files.stats.median / results.fff_files.stats.median
  print(string.format("  File search: fff is %.1fx %s than fd", math.max(ratio, 1/ratio), ratio > 1 and "faster" or "slower"))
end
if results.fff_grep.stats and results.rg_grep.stats then
  local ratio = results.rg_grep.stats.median / results.fff_grep.stats.median
  print(string.format("  Grep:        fff is %.1fx %s than rg", math.max(ratio, 1/ratio), ratio > 1 and "faster" or "slower"))
end
print(sep)
print("")
