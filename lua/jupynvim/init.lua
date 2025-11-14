-- JupyTerm: run "notebook cells" in an IPython (or Python) REPL inside a
-- right-hand vertical terminal split. Cells are '# %%' blocks or fenced
-- ```python blocks in Markdown.

local M = {}

-- ───────────────────────── State & defaults ─────────────────────────
local S = {
  job = nil, -- terminal job id
  win = nil, -- output window id
  buf = nil, -- output buffer id
  opts = {
    kernel_cmd = { 'ipython', '--colors=Linux', '--InteractiveShell.simple_prompt=False', '-i' },
    split_width = 0.42, -- fraction of columns for the vsplit
    map = true, -- install default keymaps
  },
}

local function echo(msg, hl)
  vim.api.nvim_echo({ { '[JupyTerm] ', 'Title' }, { msg, hl or 'None' } }, false, {})
end
local function running()
  return S.job and vim.fn.jobwait({ S.job }, 0)[1] == -1
end

local function pick_kernel()
  if S.opts.kernel_cmd then
    return S.opts.kernel_cmd
  end
  if vim.fn.executable 'ipython' == 1 then
    return { 'ipython', '--simple-prompt', '-i' }
  end
  if vim.fn.executable 'python3' == 1 then
    return { 'python3', '-u', '-i', '-q' }
  end
  return nil
end

-- ───────────────────────── Output vsplit ─────────────────────────
local function ensure_vsplit()
  if S.win and vim.api.nvim_win_is_valid(S.win) and S.buf and vim.api.nvim_buf_is_valid(S.buf) then
    return
  end
  local back = vim.api.nvim_get_current_win()
  vim.cmd 'vsplit'
  S.win = vim.api.nvim_get_current_win()

  local width = math.max(24, math.floor(vim.o.columns * (S.opts.split_width or 0.42)))
  pcall(vim.api.nvim_win_set_width, S.win, width)

  vim.wo[S.win].number = false
  vim.wo[S.win].relativenumber = false
  vim.wo[S.win].wrap = true
  vim.wo[S.win].cursorline = false

  vim.cmd 'enew'
  S.buf = vim.api.nvim_get_current_buf()
  vim.bo[S.buf].bufhidden = 'hide'
  vim.bo[S.buf].filetype = 'jupyterm'

  vim.fn.win_gotoid(back)
end

function M.out()
  ensure_vsplit()
  if S.win then
    vim.fn.win_gotoid(S.win)
  end
end

-- ───────────────────────── Kernel lifecycle ─────────────────────────
function M.start()
  if running() then
    echo('Kernel already running ✓', 'MoreMsg')
    return
  end
  local cmd = pick_kernel()
  if not cmd then
    echo('No ipython/python found on PATH', 'ErrorMsg')
    return
  end

  ensure_vsplit()

  local back = vim.api.nvim_get_current_win()
  vim.fn.win_gotoid(S.win)
  vim.cmd 'enew' -- fresh, unmodified buffer
  S.buf = vim.api.nvim_get_current_buf()

  S.job = vim.fn.termopen(cmd, {
    on_exit = function(_, code, _)
      vim.schedule(function()
        echo('Kernel exited (' .. code .. ')', 'WarningMsg')
      end)
    end,
  })
  if S.job <= 0 then
    echo('Failed to start kernel', 'ErrorMsg')
    vim.fn.win_gotoid(back)
    return
  end

  vim.fn.win_gotoid(back)
  echo('Kernel started ✓', 'MoreMsg')
end

function M.stop()
  if not running() then
    echo('No running kernel', 'WarningMsg')
    return
  end
  vim.fn.jobstop(S.job)
  echo('Kernel stopped', 'MoreMsg')
end

function M.interrupt()
  if not running() then
    echo('No running kernel', 'WarningMsg')
    return
  end
  vim.fn.chansend(S.job, '\003') -- Ctrl-C
  echo('Interrupted', 'MoreMsg')
end

function M.restart()
  M.stop()
  vim.defer_fn(M.start, 150)
end

-- ───────────────────────── Cell helpers ─────────────────────────
local function get_cell()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local s, e

  if ft == 'markdown' then
    local in_py = false
    for i = 1, #lines do
      local L = lines[i]
      if L:match '^```%s*python' then
        in_py = true
        if i <= cur and not s then
          s = i + 1
        end
      elseif L:match '^```' and in_py then
        if i >= cur then
          e = i - 1
          break
        else
          in_py = false
          s = nil
        end
      end
    end
  end

  if not s then
    for i = cur, 1, -1 do
      if lines[i]:match '^%s*#%s*%%' then
        s = i + 1
        break
      end
    end
    if not s then
      s = 1
    end
    for i = cur + 1, #lines do
      if lines[i]:match '^%s*#%s*%%' then
        e = i - 1
        break
      end
    end
  end

  if not e then
    e = #lines
  end
  return vim.list_slice(lines, s, e)
end

local function get_visual()
  local _, ls, cs = unpack(vim.fn.getpos "'<")
  local _, le, ce = unpack(vim.fn.getpos "'>")
  if ls > le or (ls == le and cs > ce) then
    ls, le, cs, ce = le, ls, ce, cs
  end
  local L = vim.api.nvim_buf_get_lines(0, ls - 1, le, false)
  if #L == 0 then
    return {}
  end
  L[1] = string.sub(L[1], cs)
  L[#L] = string.sub(L[#L], 1, ce)
  return L
end

-- ───────────────────────── Execution ─────────────────────────
function M.send(cells)
  if type(cells) == 'string' then
    cells = { cells }
  end
  if not running() then
    M.start()
  end
  if not running() then
    return
  end

  local BP_START = '\27[200~'
  local BP_END = '\27[201~'

  for _, cell in ipairs(cells) do
    -- If the cell is a string, just use it directly.
    -- If it's a table (list of lines), join them first.
    local payload = type(cell) == 'table' and table.concat(cell, '\n') or cell
    vim.fn.chansend(S.job, BP_START .. payload .. '\n' .. BP_END .. '\n')
  end

  --vim.fn.chansend(S.job, '\n')
end

function M.cell()
  local chunk = get_cell()
  if #chunk == 0 then
    echo('Empty cell', 'WarningMsg')
    return
  end
  M.send(chunk)
end

function M.sel()
  local chunk = get_visual()
  if #chunk == 0 then
    echo('No selection', 'WarningMsg')
    return
  end
  M.send(chunk)
end

function M.file()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if #lines == 0 then
    echo('Empty buffer', 'WarningMsg')
    return
  end

  local cells = {}
  local current = {}
  for _, line in ipairs(lines) do
    if line:match '^%s*#%s*%%' then
      if #current > 0 then
        table.insert(cells, current)
        current = {}
      end
    else
      table.insert(current, line)
    end
  end
  if #current > 0 then
    table.insert(cells, current)
  end

  M.send(cells)
end

-- ───────────────────────── Setup ─────────────────────────
function M.setup(opts)
  S.opts = vim.tbl_deep_extend('force', S.opts, opts or {})

  vim.api.nvim_create_user_command('JupyStart', M.start, {})
  vim.api.nvim_create_user_command('JupyStop', M.stop, {})
  vim.api.nvim_create_user_command('JupyRestart', M.restart, {})
  vim.api.nvim_create_user_command('JupyInterrupt', M.interrupt, {})
  vim.api.nvim_create_user_command('JupyCell', M.cell, {})
  vim.api.nvim_create_user_command('JupySel', M.sel, { range = true })
  vim.api.nvim_create_user_command('JupyFile', M.file, {})
  vim.api.nvim_create_user_command('JupyOut', M.out, {})

  if S.opts.map then
    local map = function(m, lhs, rhs, desc)
      vim.keymap.set(m, lhs, rhs, { desc = 'Jupy: ' .. desc })
    end
    map('n', '<leader>js', M.start, 'start kernel')
    map('n', '<leader>jk', M.stop, 'stop kernel')
    map('n', '<leader>jr', M.restart, 'restart kernel')
    map('n', '<leader>jc', M.cell, 'run cell')
    map('x', '<leader>jc', M.sel, 'run selection')
    map('n', '<leader>jf', M.file, 'run file')
    map('n', '<leader>jo', M.out, 'focus output split')
  end
end

return M
