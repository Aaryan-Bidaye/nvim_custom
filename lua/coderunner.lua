-- lua/code_runner.lua
-- Minimal code runner for Neovim using togterm for float/split terminals.

local M = {}

-- Try to load togterm (your custom terminal toggler)
local has_togterm, togterm = pcall(require, 'togterm')

-- Default configuration
local default_config = {
  -- How to open terminal: "float" or "split"
  terminal = 'split',

  -- Float window options (kept for API compatibility, not used directly now)
  float = {
    width = 0.9,
    height = 0.4,
    border = 'rounded',
  },

  -- Horizontal split options (kept for API compatibility)
  split = {
    size = 15, -- height of the split (used only for fallback)
  },

  -- Per-filetype run commands.
  -- {file} will be replaced with the actual file path.
  runners = {
    python = 'python3 {file}',
    lua = 'lua {file}',
    javascript = 'node {file}',
    typescript = 'ts-node {file}',
    sh = 'bash {file}',
    zsh = 'zsh {file}',

    c = 'gcc {file} -o /tmp/a.out && /tmp/a.out',
    cpp = 'g++ {file} -std=c++17 -O2 -o /tmp/a.out && /tmp/a.out',

    -- Compile all .java files in the directory, then run the class
    -- matching the current file name (supports multiple classes).
    java = 'javac *.java && java {classname}',

    -- Add more if you want:
    -- rust = "cargo run",
    -- go   = "go run {file}",
  },
}

local config = vim.deepcopy(default_config)

-- Utility: get project root (or fallback to current file dir)
local function get_project_root()
  local bufname = vim.api.nvim_buf_get_name(0)
  local cwd = vim.fn.getcwd()

  if bufname == '' then
    return cwd
  end

  -- Try to use LSP root if available
  local clients = vim.lsp.get_active_clients { bufnr = 0 }
  for _, client in ipairs(clients) do
    local workspace_folders = client.config.workspace_folders
    local root_dir = client.config.root_dir
    if workspace_folders and #workspace_folders > 0 then
      return vim.uri_to_fname(workspace_folders[1].uri)
    elseif root_dir then
      return root_dir
    end
  end

  -- Fallback to file directory
  local file_dir = vim.fn.fnamemodify(bufname, ':p:h')
  return file_dir ~= '' and file_dir or cwd
end

-- ─────────────── fallback terminal (old behavior) ───────────────

local function open_float()
  local ui = vim.api.nvim_list_uis()[1]
  local w = math.floor(ui.width * config.float.width)
  local h = math.floor(ui.height * config.float.height)
  local row = math.floor((ui.height - h) / 2)
  local col = math.floor((ui.width - w) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = w,
    height = h,
    row = row,
    col = col,
    border = config.float.border,
    style = 'minimal',
  })

  vim.api.nvim_win_set_option(win, 'winblend', 0)

  return buf, win
end

local function open_split()
  vim.cmd('belowright ' .. config.split.size .. 'split')
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  return buf, win
end

local function open_terminal_builtin()
  if config.terminal == 'split' then
    return open_split()
  else
    return open_float()
  end
end

local function run_with_builtin(cmd, root)
  local term_buf, _ = open_terminal_builtin()

  vim.fn.termopen(vim.o.shell, {
    cwd = root,
    on_exit = function(_, code, _)
      if code ~= 0 then
        vim.notify('Command exited with code ' .. code, vim.log.levels.ERROR)
      end
    end,
  })

  -- Small delay so shell starts, then send command
  vim.defer_fn(function()
    local chan = vim.b.terminal_job_id
    if not chan then
      return
    end
    vim.fn.chansend(chan, cmd .. '\n')
  end, 20)

  vim.api.nvim_buf_set_option(term_buf, 'buflisted', false)
end

-- ─────────────── TogTerm integration ───────────────

local function run_with_togterm(cmd, root)
  local mode = (config.terminal == 'float') and 'float' or 'split'
  local opts = { startinsert = false }

  -- Call your toggler once; if it closed an existing term instead of opening,
  -- call it again to force it open for this cwd.
  if mode == 'float' then
    togterm.toggle_float(opts)
    if vim.bo.buftype ~= 'terminal' then
      togterm.toggle_float(opts)
    end
  else
    togterm.toggle_split(opts)
    if vim.bo.buftype ~= 'terminal' then
      togterm.toggle_split(opts)
    end
  end

  -- At this point the current window should be the terminal window for this cwd
  local term_win = vim.api.nvim_get_current_win()
  local term_buf = vim.api.nvim_win_get_buf(term_win)
  local jid = vim.b[term_buf].terminal_job_id

  if not jid then
    vim.notify('No terminal job found in togterm buffer', vim.log.levels.ERROR)
    return
  end

  local full_cmd = 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. cmd .. '\n'
  vim.fn.chansend(jid, full_cmd)

  -- Drop the user into insert mode so they can see output / interact
  vim.cmd 'startinsert'
end

-- ─────────────── main command builder ───────────────

local function build_command(ft, file)
  local runner = config.runners[ft]
  if not runner then
    return nil, 'No runner configured for filetype: ' .. ft
  end

  -- Java needs special handling for classname
  if ft == 'java' then
    local classname = vim.fn.fnamemodify(file, ':t:r')
    runner = runner:gsub('{classname}', classname)
  end

  runner = runner:gsub('{file}', vim.fn.shellescape(file))
  return runner, nil
end

-- ─────────────── public API ───────────────

function M.run()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == '' then
    vim.notify('No file name (buffer is not saved). Save the file first.', vim.log.levels.WARN)
    return
  end

  -- Save buffer first so we run the latest changes
  vim.cmd 'write'

  local file = vim.fn.fnamemodify(bufname, ':p')
  local ft = vim.bo.filetype

  local cmd, err = build_command(ft, file)
  if not cmd then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local root = get_project_root()

  if has_togterm then
    run_with_togterm(cmd, root)
  else
    -- Fallback if togterm isn't available for some reason
    run_with_builtin(cmd, root)
  end
end

function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend('force', default_config, opts)

  -- Default keymaps if user wants
  if opts.set_keymaps ~= false then
    vim.keymap.set('n', '<leader>r', M.run, { desc = 'Run current file', silent = true })
  end
end

return M
