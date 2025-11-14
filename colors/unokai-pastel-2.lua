-- unokai-pastel.lua
-- Pastel Monokai (Unokai) with a bit more contrast.

vim.o.termguicolors = true
vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' == 1 then
  vim.cmd 'syntax reset'
end
vim.o.background = 'dark'
vim.g.colors_name = 'unokai-pastel'

-- Pastel palette (slightly higher contrast)
local p = {
  -- Darker bg, brighter fg
  bg = '#1b1c18',
  bg_alt = '#151611',
  surface = '#252720',
  overlay = '#2f3128',

  fg = '#f8f8f2',
  muted = '#b0b1a6',
  comment = '#7c7a68',

  -- Pastel accents with a bit more punch
  pink = '#f27b9b', -- statements/keywords
  coral = '#f7a46e', -- operators/special
  yellow = '#f6df8b', -- strings
  green = '#9adf72', -- identifiers/OK (closer to a6e22e vibe)
  aqua = '#7fdacb', -- functions/params
  blue = '#7aa2ff', -- types/info
  purple = '#c695ff', -- preproc/defines
  red = '#ff6c8c', -- errors
  orange = '#ffb86c', -- warnings
  cyan = '#8ef8ff', -- spare accent

  border = '#3f4036',
  subtle = '#9f9f93',
  selection = '#36392f',
  cursorln = '#292c23',
  dim = '#808074',
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
hi('TabLineSel', { fg = p.bg, bg = p.aqua, bold = true })
hi('TabLineFill', { bg = p.surface })

hi('Visual', { bg = p.selection })
hi('Search', { fg = p.bg, bg = p.yellow, bold = true })
hi('IncSearch', { fg = p.bg, bg = p.coral, bold = true })
hi('MatchParen', { fg = p.cyan, bold = true })
hi('Directory', { fg = p.aqua, bold = true })
hi('Title', { fg = p.pink, bold = true })

-- Base syntax (Vim)
hi('Comment', { fg = p.comment, italic = true })
hi('Constant', { fg = p.coral })
hi('String', { fg = p.yellow })
hi('Character', { fg = p.yellow })
hi('Number', { fg = p.purple })
hi('Boolean', { fg = p.pruple })
hi('Float', { fg = p.purple })

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

-- Telescope
hi('TelescopeNormal', { fg = p.fg, bg = p.surface })
hi('TelescopeBorder', { fg = p.border, bg = p.surface })
hi('TelescopeSelection', { fg = p.bg, bg = p.orange })
hi('TelescopeMatching', { fg = p.fg, bold = true })

-- Treesitter
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
hi('@punctuation.bracket', { fg = p.pink })
hi('@punctuation.delimiter', { fg = p.fg })
hi('@tag', { fg = p.orange })
hi('@attribute', { fg = p.purple })

-- Yank highlight
hi('YankHighlight', { fg = p.bg, bg = p.orange, bold = true })
