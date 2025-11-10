-- unokai-pastel.lua
-- A pastel Monokai (Unokai) variant: softer hues, lower contrast, cozy glow.

vim.o.termguicolors = true
vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' == 1 then
  vim.cmd 'syntax reset'
end
vim.g.colors_name = 'unokai-pastel'

-- Pastel palette (Monokai-inspired)
local p = {
  bg = '#22231f', -- softer than classic Monokai
  bg_alt = '#1b1c18',
  surface = '#2a2c26',
  overlay = '#34362e',

  fg = '#f5f5f1',
  muted = '#a6a69a',
  comment = '#8b8a7a',

  -- Pastel accents (gentler than neon Monokai)
  pink = '#f28fad', -- statements/keywords
  coral = '#f8bd96', -- operators/special
  yellow = '#f9e2af', -- strings
  green = '#a6e3a1', -- identifiers/OK (pastel a6e22e vibe)
  aqua = '#94e2d5', -- functions/params
  blue = '#89b4fa', -- types/info
  purple = '#cbb6f7', -- preproc/defines
  red = '#f38ba8', -- errors
  orange = '#fab387', -- warnings
  cyan = '#b4f9f8',

  -- UI bits
  border = '#3b3d35',
  subtle = '#9a9a90',
  selection = '#3f4237',
  cursorln = '#2f322a',
  dim = '#6f6e62',
}

local function hi(g, o)
  vim.api.nvim_set_hl(0, g, o)
end

-- Core UI
hi('Normal', { fg = p.fg, bg = p.bg })
hi('NormalNC', { fg = p.fg, bg = p.bg })
hi('NormalFloat', { fg = p.fg, bg = p.surface })
hi('FloatBorder', { fg = p.border, bg = p.surface })
hi('WinSeparator', { fg = p.border })
hi('SignColumn', { bg = p.bg })
hi('ColorColumn', { bg = p.cursorln })
hi('CursorLine', { bg = p.cursorln })
hi('CursorColumn', { bg = p.cursorln })
hi('CursorLineNr', { fg = p.orange, bold = true })
hi('LineNr', { fg = p.dim })
hi('VertSplit', { fg = p.border })
hi('StatusLine', { fg = p.fg, bg = p.surface })
hi('StatusLineNC', { fg = p.dim, bg = p.surface })
hi('Pmenu', { fg = p.fg, bg = p.surface })
hi('PmenuSel', { fg = p.bg, bg = p.orange, bold = true })
hi('PmenuSbar', { bg = p.overlay })
hi('PmenuThumb', { bg = p.border })
hi('TabLine', { fg = p.dim, bg = p.surface })
hi('TabLineSel', { fg = p.bg, bg = p.blue, bold = true })
hi('TabLineFill', { bg = p.surface })
hi('Visual', { bg = p.selection })
hi('Search', { fg = p.bg, bg = p.yellow, bold = true })
hi('IncSearch', { fg = p.bg, bg = p.coral, bold = true })
hi('MatchParen', { fg = p.aqua, bold = true })
hi('Directory', { fg = p.blue, bold = true })
hi('Title', { fg = p.pink, bold = true })

-- Base syntax (Vim)
hi('Comment', { fg = p.comment, italic = true })
hi('Constant', { fg = p.coral })
hi('String', { fg = p.yellow })
hi('Character', { fg = p.yellow })
hi('Number', { fg = p.coral })

hi('Boolean', { fg = p.coral })
hi('Float', { fg = p.coral })

hi('Identifier', { fg = p.green })
hi('Function', { fg = p.aqua })
hi('Statement', { fg = p.pink })
hi('Conditional', { fg = p.pink })
hi('Repeat', { fg = p.pink })
hi('Label', { fg = p.orange })
hi('Operator', { fg = p.coral })
hi('Keyword', { fg = p.pink })
hi('Exception', { fg = p.pink })

hi('PreProc', { fg = p.purple })
hi('Include', { fg = p.purple })
hi('Define', { fg = p.purple })
hi('Macro', { fg = p.purple })
hi('PreCondit', { fg = p.purple })

hi('Type', { fg = p.blue })
hi('StorageClass', { fg = p.blue })
hi('Structure', { fg = p.blue })
hi('Typedef', { fg = p.blue })

hi('Special', { fg = p.aqua })
hi('SpecialChar', { fg = p.aqua })
hi('Tag', { fg = p.orange })
hi('Delimiter', { fg = p.subtle })
hi('SpecialComment', { fg = p.muted, italic = true })
hi('Todo', { fg = p.bg, bg = p.yellow, bold = true })

-- Diagnostics
hi('DiagnosticError', { fg = p.red })
hi('DiagnosticWarn', { fg = p.orange })
hi('DiagnosticInfo', { fg = p.blue })
hi('DiagnosticHint', { fg = p.aqua })
hi('DiagnosticOk', { fg = p.green })

-- LSP
hi('LspReferenceText', { bg = p.selection })
hi('LspReferenceRead', { bg = p.selection })
hi('LspReferenceWrite', { bg = p.selection })
hi('LspSignatureActiveParameter', { fg = p.purple, bold = true })

-- Diff
hi('DiffAdd', { fg = p.green })
hi('DiffChange', { fg = p.orange })
hi('DiffDelete', { fg = p.red })
hi('DiffText', { fg = p.blue, bold = true })

-- Git signs
hi('GitSignsAdd', { fg = p.green })
hi('GitSignsChange', { fg = p.orange })
hi('GitSignsDelete', { fg = p.red })

-- Telescope (if used)
hi('TelescopeNormal', { fg = p.fg, bg = p.surface })
hi('TelescopeBorder', { fg = p.border, bg = p.surface })
hi('TelescopeSelection', { fg = p.bg, bg = p.rose or p.orange })
hi('TelescopeMatching', { fg = p.fg, bold = true })

-- Treesitter (key groups)
hi('@comment', { link = 'Comment' })
hi('@string', { link = 'String' })
hi('@number', { link = 'Number' })
hi('@float', { link = 'Float' })
hi('@boolean', { link = 'Boolean' })
hi('@constant', { link = 'Constant' })
hi('@constant.builtin', { fg = p.coral })
hi('@constructor', { fg = p.blue })
hi('@type', { link = 'Type' })
hi('@type.builtin', { fg = p.blue })
hi('@type.qualifier', { fg = p.purple })
hi('@variable', { fg = p.green })
hi('@variable.builtin', { fg = p.pink })
hi('@field', { fg = p.green })
hi('@property', { fg = p.green })
hi('@parameter', { fg = p.aqua })
hi('@function', { link = 'Function' })
hi('@function.call', { fg = p.aqua })
hi('@function.builtin', { fg = p.aqua })
hi('@method', { fg = p.aqua })
hi('@operator', { fg = p.coral })
hi('@keyword', { link = 'Keyword' })
hi('@keyword.function', { fg = p.pink })
hi('@keyword.return', { fg = p.pink })
hi('@punctuation', { fg = p.subtle })
hi('@punctuation.bracket', { fg = p.subtle })
hi('@punctuation.delimiter', { fg = p.subtle })
hi('@tag', { fg = p.orange })
hi('@attribute', { fg = p.purple })

-- Optional: visual yank highlight group you can use in your autocmd
-- (Since you mentioned wanting orange flash previously)
hi('YankHighlight', { fg = p.bg, bg = p.orange, bold = true })
