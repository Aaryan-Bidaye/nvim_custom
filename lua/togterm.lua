-- lua/togterm_plus.lua
---@class TogTermOpts
---@field width? integer
---@field height? integer
---@field startinsert? boolean  -- default true

local M = {}

-- ───────────────────────── state ─────────────────────────
local state = {
  win = nil, ---@type integer|nil
  mode = nil, ---@type "float"|"split"|nil
  terms = {}, ---@type table<string, integer>  -- cwd -> buf
}

-- ─────────────────────── utilities ───────────────────────
local function to_int(n, fallback)
  if n == nil then
    return math.floor(tonumber(fallback or 0))
  end
  local num = tonumber(n) or tonumber(fallback or 0)
  if num >= 0 then
    return math.floor(num)
  else
    return -math.floor(-num)
  end
end

local function clamp(x, lo, hi)
  if x < lo then
    return lo
  end
  if x > hi then
    return hi
  end
  return x
end

local function close_if_open()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win, state.mode = nil, nil
end

local function job_is_alive(job_id)
  if type(job_id) ~= 'number' or job_id <= 0 then
    return false
  end
  local ok = vim.fn.jobwait({ job_id }, 0)
  return ok and ok[1] == -1
end

local function get_current_dir()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= '' then
    local dir = vim.fn.fnamemodify(bufname, ':p:h')
    if vim.fn.isdirectory(dir) == 1 then
      return dir
    end
  end
  return vim.fn.getcwd()
end

local function get_terminal_cwd(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= 'terminal' then
    return nil
  end
  local jid = vim.b[buf].terminal_job_id
  if not jid then
    return nil
  end
  local pid = vim.fn.jobpid(jid)
  if not pid or pid <= 0 then
    return vim.b[buf].terminal_cwd
  end

  -- Linux: /proc/<pid>/cwd
  local ok, cwd = pcall(vim.loop.fs_readlink, '/proc/' .. pid .. '/cwd')
  if ok and cwd then
    return cwd
  end

  -- macOS: lsof
  local handle = io.popen(string.format('lsof -a -p %d -d cwd -Fn 2>/dev/null | grep "^n" | cut -c2-', pid))
  if handle then
    local out = handle:read '*a' or ''
    handle:close()
    out = out:gsub('%s+$', '')
    if out ~= '' then
      return out
    end
  end

  return vim.b[buf].terminal_cwd
end

-- ──────────────── transparency / highlights ───────────────
local function apply_float_highlights()
  -- transparent float with subtle border
  vim.api.nvim_set_hl(0, 'FloatingTermNormal', { bg = 'NONE' })
  vim.api.nvim_set_hl(0, 'FloatingTermBorder', { bg = 'NONE' })
end

local function set_win_opts(win)
  vim.api.nvim_set_option_value('winblend', 0, { win = win })
  vim.api.nvim_set_option_value('number', false, { win = win })
  vim.api.nvim_set_option_value('relativenumber', false, { win = win })
  vim.api.nvim_set_option_value('signcolumn', 'no', { win = win })
  vim.api.nvim_set_option_value('winhighlight', 'Normal:FloatingTermNormal,FloatBorder:FloatingTermBorder', { win = win })
end

-- ─────────────── persistent term per directory ────────────
local function ensure_term_buf()
  local cwd = get_current_dir()
  local existing = state.terms[cwd]

  if existing and vim.api.nvim_buf_is_valid(existing) and vim.bo[existing].buftype == 'terminal' then
    local jid = vim.b[existing].terminal_job_id
    if not job_is_alive(jid) then
      vim.api.nvim_buf_call(existing, function()
        local shell = (vim.o.shell ~= '' and vim.o.shell) or '/bin/sh'
        vim.fn.termopen(shell, { cwd = cwd })
      end)
    end
    return existing
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = true

  vim.api.nvim_buf_call(buf, function()
    local shell = (vim.o.shell ~= '' and vim.o.shell) or '/bin/sh'
    vim.fn.termopen(shell, { cwd = cwd })
  end)

  vim.b[buf].terminal_cwd = cwd

  -- quick close in normal mode
  vim.keymap.set('n', 'q', function()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_win_close(state.win, true)
    end
  end, { buffer = buf, nowait = true, silent = true })

  state.terms[cwd] = buf
  return buf
end

-- ───────────────────────── toggles ────────────────────────
---@param opts? TogTermOpts
function M.toggle_float(opts)
  local cwd = get_current_dir()

  if state.mode == 'float' and state.win and vim.api.nvim_win_is_valid(state.win) then
    local curbuf = vim.api.nvim_win_get_buf(state.win)
    if vim.b[curbuf].terminal_cwd == cwd then
      close_if_open()
      return
    end
  end
  close_if_open()

  opts = opts or {}
  local columns = to_int(vim.o.columns, 120)
  local lines = to_int(vim.o.lines, 40) - to_int(vim.o.cmdheight, 1) - 2

  local def_w = to_int(math.floor(columns * 0.8 + 0.5), 80)
  local def_h = to_int(math.floor(lines * 0.8 + 0.5), 20)
  local width = clamp(to_int(opts.width or def_w, def_w), 10, columns - 2)
  local height = clamp(to_int(opts.height or def_h, def_h), 3, lines - 2)

  local row = to_int(math.floor((lines - height) / 2), 0)
  local col = to_int(math.floor((columns - width) / 2), 0)

  local win_opts = {
    style = 'minimal',
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    border = 'rounded',
  }

  local buf = ensure_term_buf()
  state.win = vim.api.nvim_open_win(buf, true, win_opts)
  state.mode = 'float'
  apply_float_highlights()
  set_win_opts(assert(state.win))

  if opts.startinsert ~= false then
    vim.cmd 'startinsert'
  end
end

---@param opts? TogTermOpts
function M.toggle_split(opts)
  local cwd = get_current_dir()

  if state.mode == 'split' and state.win and vim.api.nvim_win_is_valid(state.win) then
    local curbuf = vim.api.nvim_win_get_buf(state.win)
    if vim.b[curbuf].terminal_cwd == cwd then
      close_if_open()
      return
    end
  end
  close_if_open()

  opts = opts or {}
  local lines = to_int(vim.o.lines, 40) - to_int(vim.o.cmdheight, 1)
  local def_h = math.max(6, to_int(math.floor(lines * 0.3 + 0.5), 12))
  local height = to_int(opts.height or def_h, def_h)

  local buf = ensure_term_buf()
  vim.cmd 'botright split'
  state.win = vim.api.nvim_get_current_win()
  state.mode = 'split'
  vim.api.nvim_win_set_buf(assert(state.win), buf)
  vim.api.nvim_win_set_height(assert(state.win), height)
  set_win_opts(assert(state.win))

  if opts.startinsert ~= false then
    vim.cmd 'startinsert'
  end
end

function M.close()
  close_if_open()
end

-- ───────────────────── UI selector ────────────────────────
function M.list_terminals()
  local terms = {}
  for stored_cwd, buf in pairs(state.terms) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal' then
      local live = get_terminal_cwd(buf) or stored_cwd
      table.insert(terms, { cwd = live, buf = buf, display = live })
    else
      state.terms[stored_cwd] = nil
    end
  end

  if #terms == 0 then
    vim.notify('No terminal buffers open', vim.log.levels.INFO)
    return
  end

  local current_buf = nil
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    current_buf = vim.api.nvim_win_get_buf(state.win)
  end

  table.sort(terms, function(a, b)
    if current_buf and a.buf == current_buf and b.buf ~= current_buf then
      return true
    end
    if current_buf and b.buf == current_buf and a.buf ~= current_buf then
      return false
    end
    return a.cwd < b.cwd
  end)

  if current_buf then
    for _, t in ipairs(terms) do
      if t.buf == current_buf then
        t.display = t.cwd .. ' [current]'
        break
      end
    end
  end

  vim.ui.select(terms, {
    prompt = 'Select terminal:',
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if not choice then
      return
    end

    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_win_set_buf(state.win, choice.buf)
      vim.api.nvim_set_current_win(state.win)
      vim.cmd 'startinsert'
    else
      -- open as float centered
      local columns = to_int(vim.o.columns, 120)
      local lines = to_int(vim.o.lines, 40) - to_int(vim.o.cmdheight, 1) - 2
      local def_w = to_int(math.floor(columns * 0.8 + 0.5), 80)
      local def_h = to_int(math.floor(lines * 0.8 + 0.5), 20)
      local width = clamp(def_w, 10, columns - 2)
      local height = clamp(def_h, 3, lines - 2)
      local row = to_int(math.floor((lines - height) / 2), 0)
      local col = to_int(math.floor((columns - width) / 2), 0)

      local win_opts = {
        style = 'minimal',
        relative = 'editor',
        row = row,
        col = col,
        width = width,
        height = height,
        border = 'rounded',
      }

      state.win = vim.api.nvim_open_win(choice.buf, true, win_opts)
      state.mode = 'float'
      apply_float_highlights()
      set_win_opts(assert(state.win))
      vim.cmd 'startinsert'
    end
  end)
end

-- ─────────────────────── keymaps ──────────────────────────
--
-- Close current float/split with Ctrl-\
vim.keymap.set({ 't', 'n' }, '<C-\\>', function()
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end, { desc = 'Close current window (float or split)' })

-- Close current floating terminal with <Esc> in terminal mode
vim.keymap.set('t', '<Esc>', function()
  -- If a terminal window exists and is floating, close it
  if state.mode == 'float' and state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
    state.win = nil
    state.mode = nil
  end
end, { noremap = true, silent = true, desc = 'Close floating terminal with <Esc>' })

-- Default mappings (you can remap these in your config)
vim.keymap.set('n', '<leader>t', function()
  M.toggle_float()
end, { desc = 'Toggle terminal (float)' })

vim.keymap.set('n', '<leader>T', function()
  M.toggle_split()
end, { desc = 'Toggle terminal (split)' })

vim.keymap.set('n', '<leader>tl', function()
  M.list_terminals()
end, { desc = 'List/switch terminals' })

return M
