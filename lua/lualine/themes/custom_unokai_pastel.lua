-- lua/lualine/themes/unokai-pastel.lua
-- Lualine theme for the Unokai Pastel colorscheme

local M = {}

-- Re-declare the palette so lualine doesn’t depend on the colorscheme file
local p = {
  bg = '#22231f',
  bg_alt = '#1b1c18',
  surface = '#2a2c26',
  cursorln = '#2f322a',
  selection = '#3f4237',
  border = '#3b3d35',

  fg = '#f5f5f1',
  comment = '#8b8a7a',

  -- Pastel accents
  pink = '#f28fad', -- replace / keyword vibe
  coral = '#f8bd96',
  yellow = '#f9e2af', -- command
  green = '#a6e3a1', -- insert
  aqua = '#94e2d5', -- normal
  blue = '#89b4fa',
  purple = '#cbb6f7', -- visual
  orange = '#fab387',
}

-- Helper to build a mode style
local function mode(a_bg)
  return {
    a = { fg = p.bg, bg = a_bg, gui = 'bold' },
    b = { fg = p.fg, bg = p.cursorln },
    c = { fg = p.comment, bg = p.surface },
  }
end

-- Modes
M.normal = mode(p.aqua) -- NORMAL → aqua
M.insert = mode(p.green) -- INSERT → green
M.visual = mode(p.purple) -- VISUAL → purple
M.replace = mode(p.pink) -- REPLACE → pink
M.command = mode(p.yellow) -- COMMAND → yellow
M.terminal = mode(p.orange) -- TERMINAL → orange

-- Inactive windows: low-contrast, flat
M.inactive = {
  a = { fg = p.comment, bg = p.bg_alt, gui = 'bold' },
  b = { fg = p.comment, bg = p.bg_alt },
  c = { fg = p.comment, bg = p.bg_alt },
}

return M
