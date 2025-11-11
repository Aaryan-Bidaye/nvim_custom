-- lua/jupyterm/inline_output.lua
-- Minimal inline-output runner:
-- - Starts a hidden IPython with a PTY (jobstart{pty=true}) so we can capture stdout.
-- - Sends a cell via %cpaste -q ... -- to handle multi-line blocks.
-- - Buffers stdout until the next "In [n]:" prompt appears, then renders
--   the captured chunk *under the cell* as virtual lines via extmarks.

local M = {}

-- Runtime state (separate from your terminal split kernel)
local S = {
  job = nil, -- job id (pty)
  chan = nil, -- channel id
  bufacc = '', -- stdout accumulator
  ready = false, -- did we see first prompt?
  ns = vim.api.nvim_create_namespace 'jupyterm_inline',
  opts = {
    kernel_cmd = nil, -- if nil, auto-pick (ipython > py)
    colors = true, -- ask IPython for colors
    prompt_pat = 'In %[%d+%]%:%s', -- regex to detect new prompt
    timeout_ms = 8000, -- wait for a prompt up to this long
    max_lines = 5000, -- clamp virtual lines
    hl_group = 'Comment', -- highlight group for output
  },
  -- extmarks we place, keyed by bufnr & cell key (start line)
  marks = {}, -- marks[bufnr][cell_key] = extmark_id
}

local function echo(msg, hl)
  vim.api.nvim_echo({ { '[JupyInline] ', 'Title' }, { msg, hl or 'None' } }, false, {})
end
local function running()
  return S.job and vim.fn.jobwait({ S.job }, 0)[1] == -1
end

local function pick_kernel()
  if S.opts.kernel_cmd and #S.opts.kernel_cmd > 0 then
    return S.opts.kernel_cmd
  end
  if vim.fn.executable 'ipython' == 1 then
    if S.opts.colors then
      return { 'ipython', '--colors=Linux', '--InteractiveShell.simple_prompt=False', '-i' }
    else
      return { 'ipython', '-i' }
    end
  end
  if vim.fn.executable 'python3' == 1 then
    return { 'python3', '-u', '-i', '-q' }
  end
  return nil
end

----------------------------------------------------------------------
-- Kernel process (hidden, PTY)
----------------------------------------------------------------------
function M.start(opts)
  S.opts = vim.tbl_deep_extend('force', S.opts, opts or {})
  if running() then
    return
  end
  local cmd = pick_kernel()
  if not cmd then
    echo('No ipython/python found on PATH', 'ErrorMsg')
    return
  end

  S.bufacc, S.ready = '', false

  S.job = vim.fn.jobstart(cmd, {
    pty = true, -- allocate PTY => we can capture stdout
    stdout_buffered = false,
    on_stdout = function(_, data, _)
      if not data then
        return
      end
      for _, line in ipairs(data) do
        -- jobstart sends nil/"" at times; guard
        if line ~= nil then
          S.bufacc = S.bufacc .. line .. '\n'
        end
      end
      -- Once IPython shows its first prompt, mark ready
      if (not S.ready) and S.bufacc:find(S.opts.prompt_pat) then
        S.ready = true
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        echo('Inline kernel exited (' .. code .. ')', 'WarningMsg')
      end)
      S.job, S.chan, S.ready = nil, nil, false
    end,
  })
  if S.job <= 0 then
    echo('Failed to start inline kernel', 'ErrorMsg')
    S.job = nil
    return
  end
end

function M.stop()
  if running() then
    vim.fn.jobstop(S.job)
  end
  S.job, S.chan, S.ready, S.bufacc = nil, nil, false, ''
end

----------------------------------------------------------------------
-- Prompt waiting & chunk extraction
----------------------------------------------------------------------
local function wait_for_prompt(timeout_ms)
  local start = vim.loop.hrtime()
  local function elapsed()
    return (vim.loop.hrtime() - start) / 1e6
  end
  while elapsed() < (timeout_ms or S.opts.timeout_ms) do
    if S.bufacc:find(S.opts.prompt_pat) then
      return true
    end
    vim.wait(10) -- yield a bit; inexpensive
  end
  return false
end

-- take everything up to the *last* prompt as an output chunk
local function pop_output_chunk()
  local acc = S.bufacc
  local last_start = nil
  local idx = 1
  while true do
    local s, e = acc:find(S.opts.prompt_pat, idx)
    if not s then
      break
    end
    last_start = s
    idx = e + 1
  end
  if not last_start then
    -- no prompt yet; return nothing (caller likely waited already)
    return nil
  end
  -- Split into: [..previous output..][prompt..rest]
  local chunk = acc:sub(1, last_start - 1)
  -- Keep from prompt to end for next round
  S.bufacc = acc:sub(last_start)
  return chunk
end

----------------------------------------------------------------------
-- Render inline beneath a cell (virtual lines)
----------------------------------------------------------------------
local function clear_cell_output(bufnr, cell_key)
  S.marks[bufnr] = S.marks[bufnr] or {}
  local id = S.marks[bufnr][cell_key]
  if id and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, S.ns, id)
  end
  S.marks[bufnr][cell_key] = nil
end

local function place_inline_output(bufnr, end_line, lines, cell_key)
  S.marks[bufnr] = S.marks[bufnr] or {}

  -- build virt_lines array: { { {text, hl}, ... } , line2, ... }
  local virt = {}
  local cap = math.min(#lines, S.opts.max_lines)
  for i = 1, cap do
    table.insert(virt, { { lines[i], S.opts.hl_group } })
  end

  -- place extmark at "line after cell end"
  local id = vim.api.nvim_buf_set_extmark(bufnr, S.ns, end_line, 0, {
    virt_lines = virt,
    virt_lines_above = false,
    hl_mode = 'combine',
  })

  -- remember it so re-runs can clear
  S.marks[bufnr][cell_key] = id
end

----------------------------------------------------------------------
-- Public: run a cell and render inline
----------------------------------------------------------------------
-- run_inline(bufnr, start_l, end_l, lines)
-- - bufnr: buffer id
-- - start_l, end_l: 0-based indices for the cell lines
-- - lines: the cell code as a list of strings (no trailing newlines)
function M.run_inline(bufnr, start_l, end_l, lines)
  if not running() then
    M.start()
  end
  if not running() then
    return
  end

  -- Wait until kernel has shown a prompt so that our chunk split works
  if not S.ready then
    if not wait_for_prompt(S.opts.timeout_ms) then
      echo('Inline kernel not ready (prompt timeout)', 'WarningMsg')
      return
    end
  end

  -- cell key = end line (stable enough; you can use start as well)
  local cell_key = tostring(start_l) .. ':' .. tostring(end_l)
  clear_cell_output(bufnr, cell_key)

  -- Send via cpaste (handles multi-line blocks robustly)
  local payload = '%cpaste -q\n' .. table.concat(lines, '\n') .. '\n--\n'
  S.bufacc = S.bufacc or ''
  local acc_before = #S.bufacc
  vim.fn.chansend(S.job, payload)

  -- Wait for the *next* prompt to appear; then capture up to it
  if not wait_for_prompt(S.opts.timeout_ms) then
    echo('No prompt after executing cell (timeout)', 'WarningMsg')
    return
  end

  local chunk = pop_output_chunk()
  if not chunk then
    return
  end

  -- Trim the echoed cpaste banner if any
  -- (Because of -q, most echoes are suppressed, but kernels vary.)
  chunk = chunk:gsub('^%s+', ''):gsub('%s+$', '')

  -- Split into lines, put as virt_lines
  local out_lines = vim.split(chunk, '\n', { plain = true })
  -- If empty, still place a subtle marker (optional)
  if #out_lines == 0 or (#out_lines == 1 and out_lines[1] == '') then
    out_lines = { ' ' }
  end
  place_inline_output(bufnr, end_l, out_lines, cell_key)
end

return M -- somewhere at top of your main file
--	local inline = require("jupyterm.inline_output")
--
--	-- helper: get current cell lines + 0-based start/end
--	local function get_cell_and_range()
--	  local bufnr = vim.api.nvim_get_current_buf()
--	  local cur   = vim.api.nvim_win_get_cursor(0)[1]
--	  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
--	  local start_l, end_l
--
--	  -- find "# %%" blocks (add your markdown fences if you like)
--	  for i = cur, 1, -1 do
--	    if lines[i]:match("^%s*#%s*%%") then start_l = i; break end
--	  end
--	  if not start_l then start_l = 1 else start_l = start_l + 1 end
--	  for i = cur + 1, #lines do
--	    if lines[i]:match("^%s*#%s*%%") then end_l = i - 1; break end
--	  end
--	  if not end_l then end_l = #lines end
--
--	  local chunk = vim.list_slice(lines, start_l, end_l)
--	  -- convert to 0-based indices for extmarks
--	  return bufnr, start_l - 1, end_l - 1, chunk
--	end
--
--	-- public command to run inline
--	function M.JupyCellInline()
--	  local bufnr, s0, e0, chunk = get_cell_and_range()
--	  if #chunk == 0 then
--	    vim.notify("[JupyTerm] Empty cell", vim.log.levels.WARN)
--	    return
--	  end
--	  inline.run_inline(bufnr, s0, e0, chunk)
--	end
--
--	-- create a user command / map
--	vim.api.nvim_create_user_command("JupyCellInline", function() M.JupyCellInline() end, {})
--	vim.keymap.set("n", "<leader>ji", function() M.JupyCellInline() end, { desc = "Jupy: run cell inline" })
