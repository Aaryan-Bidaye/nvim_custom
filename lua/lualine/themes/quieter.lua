-- lua/lualine/themes/quiet_gray.lua
-- Lualine theme matching the quiet_gray colorscheme

local p = {
  bg = '#111213',
  bg_alt = '#171819',
  surface = '#1c1d1f',
  overlay = '#222428',

  fg = '#e4e4e4',
  dim = '#b3b3b3',
  subtle = '#8d8d8d',
  comment = '#6a6a6a',

  cool = '#a6b3c4', -- types
  warm = '#c4b7a6', -- strings
  cyan = '#9ab8bf', -- functions/info
  amber = '#c7aa7a', -- keywords/warnings
  red = '#d37b7b', -- errors
}

local M = {}

-- Each mode has sections:
-- a: left block (mode)
-- b: middle-left (branch, diff)
-- c: main area (filename, etc)
-- x,y,z: right side
M.normal = {
  a = { fg = p.bg, bg = p.fg, gui = 'bold' },
  b = { fg = p.fg, bg = p.overlay },
  c = { fg = p.dim, bg = p.surface },
}

M.insert = {
  a = { fg = p.bg, bg = p.cyan, gui = 'bold' },
  b = { fg = p.fg, bg = p.overlay },
  c = { fg = p.dim, bg = p.surface },
}

M.visual = {
  a = { fg = p.bg, bg = p.amber, gui = 'bold' },
  b = { fg = p.fg, bg = p.overlay },
  c = { fg = p.dim, bg = p.surface },
}

M.replace = {
  a = { fg = p.bg, bg = p.red, gui = 'bold' },
  b = { fg = p.fg, bg = p.overlay },
  c = { fg = p.dim, bg = p.surface },
}

M.command = {
  a = { fg = p.bg, bg = p.cool, gui = 'bold' },
  b = { fg = p.fg, bg = p.overlay },
  c = { fg = p.dim, bg = p.surface },
}

M.inactive = {
  a = { fg = p.subtle, bg = p.bg_alt, gui = 'bold' },
  b = { fg = p.subtle, bg = p.bg_alt },
  c = { fg = p.comment, bg = p.bg_alt },
}

return M
