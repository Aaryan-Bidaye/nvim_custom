-- lua/jupyterm/ipynb.lua
-- Minimal .ipynb open/run/save integration for Neovim.
-- Renders cells into a normal text buffer with separators:
--   # %%               -> code cell
--   # %% [markdown]    -> markdown cell (lines shown as "# " prefixed)
-- On save, rebuilds a notebook JSON and writes back to the same .ipynb file.

local M = {}

local state = {
  -- per-buffer notebook state
  bufs = setmetatable({}, { __mode = 'k' }), -- weak keys (bufnr)
  opts = {
    -- function(cells_as_arrays_of_lines) -> run cells
    -- You MUST provide this in setup to hook your sender.
    send = nil,

    -- keep nbformat header defaults if opening a raw buffer (no existing JSON)
    nbformat = 4,
    nbformat_minor = 5,

    -- control whether we prefix markdown lines with "# " when rendering
    md_prefix = '# ',
  },
}
-- Turn a notebook "source" (string or list of strings, possibly with '\n')
-- into a clean list of lines with no embedded newlines.
local function normalize_source(src)
  local lines = {}
  if type(src) == 'string' then
    src = vim.split(src, '\n', { plain = true })
  end
  for _, s in ipairs(src or {}) do
    -- Split any leftover newlines and strip trailing \r
    if s:find '\n' then
      local parts = vim.split(s, '\n', { plain = true })
      for _, p in ipairs(parts) do
        lines[#lines + 1] = (p:gsub('\r$', ''))
      end
    else
      lines[#lines + 1] = (s:gsub('\r$', ''))
    end
  end
  return lines
end

local function json_decode(s)
  local ok, j = pcall(function()
    if vim.json and vim.json.decode then
      return vim.json.decode(s)
    end
    return vim.fn.json_decode(s)
  end)
  return ok and j or nil
end

local function json_encode(tbl)
  local ok, s = pcall(function()
    if vim.json and vim.json.encode then
      return vim.json.encode(tbl)
    end
    return vim.fn.json_encode(tbl)
  end)
  return ok and s or nil
end

local function read_file(path)
  local fd = vim.loop.fs_open(path, 'r', 438)
  if not fd then
    return nil, 'open failed'
  end
  local stat = vim.loop.fs_fstat(fd)
  local data = vim.loop.fs_read(fd, stat.size, 0)
  vim.loop.fs_close(fd)
  return data, nil
end

local function write_file(path, data)
  local fd = vim.loop.fs_open(path, 'w', 420)
  if not fd then
    return false, 'open failed'
  end
  vim.loop.fs_write(fd, data, 0)
  vim.loop.fs_close(fd)
  return true
end

------------------------------------------------------------
-- Render notebook into buffer
------------------------------------------------------------
local function render_to_buffer(buf, nb)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

  local out = {}
  for _, cell in ipairs(nb.cells or {}) do
    if cell.cell_type == 'markdown' then
      table.insert(out, '# %% [markdown]')
      local src = normalize_source(cell.source)
      for _, ln in ipairs(src) do
        table.insert(out, (state.opts.md_prefix or '# ') .. ln)
      end
      table.insert(out, '')
    elseif cell.cell_type == 'code' then
      table.insert(out, '# %%')
      local src = normalize_source(cell.source)
      for _, ln in ipairs(src) do
        table.insert(out, ln)
      end
      table.insert(out, '')
    else
      table.insert(out, '# %% [markdown]')
      table.insert(out, (state.opts.md_prefix or '# ') .. ('[unsupported cell_type: ' .. tostring(cell.cell_type) .. ']'))
      table.insert(out, '')
    end
  end

  if #out == 0 then
    out = { '# %%', '' }
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
end

------------------------------------------------------------
-- Parse buffer into notebook cell table
------------------------------------------------------------
local function strip_md_prefix(line)
  local p = state.opts.md_prefix or '# '
  if p ~= '' and line:sub(1, #p) == p then
    return line:sub(#p + 1)
  end
  -- also accept "# " or "#" as fallbacks
  local s = line:match '^%s*#%s?(.*)$'
  if s then
    return s
  end
  return line
end

local function split_buffer_into_cells(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local cells = {}

  local cur_type = nil
  local cur = {}

  local function push()
    if not cur_type then
      return
    end
    -- trim leading/trailing blank lines
    local s, e = 1, #cur
    while s <= e and cur[s]:match '^%s*$' do
      s = s + 1
    end
    while e >= s and cur[e]:match '^%s*$' do
      e = e - 1
    end
    local body = {}
    for i = s, e do
      body[#body + 1] = cur[i]
    end

    local source = vim.deepcopy(body)
    if cur_type == 'markdown' then
      -- remove comment prefix for markdown
      for i, ln in ipairs(source) do
        source[i] = strip_md_prefix(ln)
      end
    end

    -- Notebook "source" is a list of lines each ending with '\n' except maybe last; we’ll keep plain list (Jupyter accepts both forms).
    table.insert(cells, {
      cell_type = cur_type,
      source = source,
      metadata = {},
      outputs = (cur_type == 'code') and {} or nil,
      execution_count = (cur_type == 'code') and vim.NIL or nil,
    })
  end

  for _, ln in ipairs(lines) do
    local hdr = ln:match '^%s*#%s*%%%s*(.*)$'
    if hdr ~= nil then
      -- New cell separator
      push()
      cur = {}
      if hdr:match '%[markdown%]' then
        cur_type = 'markdown'
      else
        cur_type = 'code'
      end
    else
      table.insert(cur, ln)
    end
  end
  push()

  return cells
end

------------------------------------------------------------
-- Public: open / save / run
------------------------------------------------------------
function M.setup(opts)
  state.opts = vim.tbl_deep_extend('force', state.opts, opts or {})

  vim.api.nvim_create_user_command('JupyNbOpen', function(cmd)
    local path = cmd.args ~= '' and cmd.args or vim.api.nvim_buf_get_name(0)
    M.open(path)
  end, { nargs = '?' })

  vim.api.nvim_create_user_command('JupyNbSave', function()
    M.save()
  end, {})

  vim.api.nvim_create_user_command('JupyNbRunAll', function()
    M.run_all()
  end, {})

  vim.api.nvim_create_user_command('JupyNbRunCell', function()
    M.run_cell()
  end, {})

  vim.api.nvim_create_user_command('JupyNbNew', function(cmd)
    -- :JupyNbNew (prompts)  or :JupyNbNew name.ipynb
    M.new(cmd.args)
  end, { nargs = '?', complete = 'file' })
end

-- Open a .ipynb into the current buffer (replaces contents)
function M.open(path)
  if path == '' then
    vim.notify('[ipynb] No file path', vim.log.levels.ERROR)
    return
  end
  local data, err = read_file(path)
  if not data then
    vim.notify('[ipynb] Read failed: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end
  local nb = json_decode(data)
  if not nb or type(nb) ~= 'table' or type(nb.cells) ~= 'table' then
    vim.notify('[ipynb] Invalid notebook JSON', vim.log.levels.ERROR)
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  state.bufs[buf] = {
    path = path,
    nb = nb,
  }
  render_to_buffer(buf, nb)
  vim.bo[buf].filetype = 'python' -- good defaults for editing code
  vim.b[buf].ipynb_mode = true
  vim.notify('[ipynb] Loaded notebook: ' .. path, vim.log.levels.INFO)
end

-- Save current buffer back into the same .ipynb (rebuild cells)
function M.save()
  local buf = vim.api.nvim_get_current_buf()
  local st = state.bufs[buf]
  if not st or not st.path then
    vim.notify('[ipynb] This buffer is not tracked as a notebook; use :JupyNbOpen', vim.log.levels.WARN)
    return
  end

  local nb_orig = st.nb or {}
  local nb = {
    nbformat = nb_orig.nbformat or state.opts.nbformat,
    nbformat_minor = nb_orig.nbformat_minor or state.opts.nbformat_minor,
    metadata = nb_orig.metadata or {},
    cells = split_buffer_into_cells(buf),
  }

  local json = json_encode(nb)
  if not json then
    vim.notify('[ipynb] JSON encode failed', vim.log.levels.ERROR)
    return
  end

  local ok, err = write_file(st.path, json)
  if not ok then
    vim.notify('[ipynb] Write failed: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end
  st.nb = nb
  vim.notify('[ipynb] Saved: ' .. st.path, vim.log.levels.INFO)
end

-- Helpers to find the current cell (in rendered buffer)
local function get_current_cell(buf)
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local s, e, cell_type

  for i = cur, 1, -1 do
    local hdr = lines[i]:match '^%s*#%s*%%%s*(.*)$'
    if hdr ~= nil then
      s = i + 1
      cell_type = (hdr:match '%[markdown%]' and 'markdown') or 'code'
      break
    end
  end
  if not s then
    s = 1
    cell_type = 'code'
  end

  for i = cur + 1, #lines do
    local hdr = lines[i]:match '^%s*#%s*%%%s*(.*)$'
    if hdr ~= nil then
      e = i - 1
      break
    end
  end
  if not e then
    e = #lines
  end

  local body = vim.list_slice(lines, s, e)
  if cell_type == 'markdown' then
    for i, ln in ipairs(body) do
      body[i] = strip_md_prefix(ln)
    end
  end
  return cell_type, body
end

-- Run current cell if it is code; markdown ignored
function M.run_cell()
  if not state.opts.send then
    vim.notify('[ipynb] opts.send not set in setup()', vim.log.levels.ERROR)
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local ctype, body = get_current_cell(buf)
  if ctype ~= 'code' then
    vim.notify('[ipynb] Current cell is markdown; not executed', vim.log.levels.WARN)
    return
  end
  if #body == 0 then
    vim.notify('[ipynb] Empty code cell', vim.log.levels.WARN)
    return
  end
  -- send expects a list of cells (each a list of lines)
  state.opts.send { body }
end

-- Run all code cells in order
function M.run_all()
  if not state.opts.send then
    vim.notify('[ipynb] opts.send not set in setup()', vim.log.levels.ERROR)
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local cells = split_buffer_into_cells(buf)
  local code_cells = {}
  for _, c in ipairs(cells) do
    if c.cell_type == 'code' and #c.source > 0 then
      -- c.source already list of lines (no newlines)
      table.insert(code_cells, c.source)
    end
  end
  if #code_cells == 0 then
    vim.notify('[ipynb] No code cells to run', vim.log.levels.WARN)
    return
  end
  state.opts.send(code_cells)
end

-- create a new .ipynb on disk and (optionally) open it
local function detect_py_ver()
  local line = vim.fn.systemlist('python3 -V')[1] or ''
  return (line:match 'Python%s+([%d%.]+)') or '3.x'
end

function M.new(path, opts)
  opts = opts or {}
  -- Ask for a name if none provided
  if not path or path == '' then
    path = vim.fn.input('New notebook name: ', 'Untitled.ipynb')
  end
  if not path:match '%.ipynb$' then
    path = path .. '.ipynb'
  end

  local nb = {
    cells = {
      {
        cell_type = 'markdown',
        metadata = {},
        -- Jupyter likes source as a list of lines (often each ending with \n)
        source = { '# New Notebook\n' },
      },
      {
        cell_type = 'code',
        metadata = {},
        execution_count = vim.NIL, -- keep the key with null (nil would drop key)
        outputs = {},
        source = { 'print("Hello World!")\n' },
      },
    },
    metadata = {
      kernelspec = {
        name = 'python3',
        language = 'python',
        display_name = 'Python 3',
      },
      language_info = {
        name = 'python',
        version = detect_py_ver(),
      },
    },
    nbformat = state.opts.nbformat,
    nbformat_minor = state.opts.nbformat_minor,
  }

  local json = json_encode(nb)
  if not json then
    vim.notify('[ipynb] JSON encode failed while creating notebook', vim.log.levels.ERROR)
    return
  end
  local ok, err = write_file(path, json)
  if not ok then
    vim.notify('[ipynb] Create failed: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end

  vim.notify('[ipynb] Created: ' .. path, vim.log.levels.INFO)

  -- Open it right away unless the caller says otherwise
  if opts.open ~= false then
    M.open(path)
  end
end

return M
