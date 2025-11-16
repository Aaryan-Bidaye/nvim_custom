-- quiet_gray.lua
-- A low-saturation gray theme inspired by "quiet", but with clearer contrast.

vim.o.termguicolors = true
vim.cmd 'highlight clear'
if vim.fn.exists 'syntax_on' == 1 then
  vim.cmd 'syntax reset'
end
vim.o.background = 'dark'
vim.g.colors_name = 'quiet_gray'

local p = {
  -- Greys
  bg = '#111213',
  bg_alt = '#171819',
  surface = '#1c1d1f',
  overlay = '#222428',

  fg = '#e4e4e4',
  dim = '#b3b3b3',
  subtle = '#8d8d8d',
  comment = '#6a6a6a',

  -- Very subtle “colored” greys (just a hint of hue)
  cool = '#a6b3c4', -- cool gray (used for types)
  warm = '#c4b7a6', -- warm gray (used for strings)
  cyan = '#9ab8bf', -- for functions / info
  amber = '#c7aa7a', -- for keywords / warnings
  red = '#d37b7b', -- for errors (still muted)
  yellow = '#d3c27b', -- for numbers / booleans
}

local function hi(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

local function link(from, to)
  vim.api.nvim_set_hl(0, from, { link = to })
end

-----------------------------------------------------------------------
-- Core UI
-----------------------------------------------------------------------
hi('Normal', { fg = p.fg, bg = p.bg })
hi('NormalNC', { fg = p.dim, bg = p.bg_alt })
hi('NormalFloat', { fg = p.fg, bg = p.surface })
hi('FloatBorder', { fg = p.overlay, bg = p.surface })
hi('WinSeparator', { fg = p.overlay, bg = p.bg })

hi('SignColumn', { fg = p.subtle, bg = p.bg })
hi('LineNr', { fg = p.subtle })
hi('CursorLineNr', { fg = p.fg, bg = p.surface, bold = true })

hi('CursorLine', { bg = p.surface })
hi('CursorColumn', { bg = p.surface })
hi('ColorColumn', { bg = p.overlay })

hi('VertSplit', { fg = p.overlay, bg = p.bg })

hi('StatusLine', { fg = p.fg, bg = p.surface })
hi('StatusLineNC', { fg = p.subtle, bg = p.surface })

hi('Pmenu', { fg = p.fg, bg = p.surface })
hi('PmenuSel', { fg = p.bg, bg = p.dim, bold = true })
hi('PmenuSbar', { bg = p.overlay })
hi('PmenuThumb', { bg = p.subtle })

hi('TabLine', { fg = p.subtle, bg = p.surface })
hi('TabLineSel', { fg = p.cyan, bg = p.overlay, bold = true })
hi('TabLineFill', { bg = p.surface })

hi('Visual', { bg = p.overlay })
hi('Search', { fg = p.bg, bg = p.dim, bold = true })
hi('IncSearch', { fg = p.bg, bg = p.amber, bold = true })
hi('MatchParen', { fg = p.cyan, bold = true })

hi('Directory', { fg = p.cyan, bold = true })
hi('Title', { fg = p.fg, bold = true })

-----------------------------------------------------------------------
-- Base syntax (Vim)
-----------------------------------------------------------------------
hi('Comment', { fg = p.comment, italic = true })

-- Literals
hi('Constant', { fg = p.warm })
hi('String', { fg = p.warm })
hi('Character', { fg = p.warm })
hi('Number', { fg = p.dim })
hi('Boolean', { fg = p.dim })
hi('Float', { fg = p.dim })

-- Identifiers / functions
hi('Identifier', { fg = p.fg })
hi('Function', { fg = p.cyan })

-- Keywords / control flow
hi('Statement', { fg = p.dim })
hi('Keyword', { fg = p.amber })
hi('Conditional', { fg = p.amber })
hi('Repeat', { fg = p.amber })
hi('Label', { fg = p.amber })
hi('Operator', { fg = p.subtle })
hi('Exception', { fg = p.amber })

-- Preprocessor
hi('PreProc', { fg = p.cool })
hi('Include', { fg = p.cool })
hi('Define', { fg = p.cool })
hi('Macro', { fg = p.cool })
hi('PreCondit', { fg = p.cool })

-- Types / structures
hi('Type', { fg = p.cool })
hi('StorageClass', { fg = p.cool })
hi('Structure', { fg = p.cool })
hi('Typedef', { fg = p.cool })

-- Specials / punctuation
hi('Special', { fg = p.dim })
hi('SpecialChar', { fg = p.dim })
hi('Tag', { fg = p.dim })
hi('Delimiter', { fg = p.subtle })
hi('SpecialComment', { fg = p.comment, italic = true })
hi('Todo', { fg = p.bg, bg = p.dim, bold = true })

-----------------------------------------------------------------------
-- Diagnostics
-----------------------------------------------------------------------
hi('Error', { fg = p.red, bold = true })
hi('ErrorMsg', { fg = p.red, bold = true })
hi('WarningMsg', { fg = p.amber })

hi('DiagnosticError', { fg = p.red })
hi('DiagnosticWarn', { fg = p.yellow })
hi('DiagnosticInfo', { fg = p.cool })
hi('DiagnosticHint', { fg = p.subtle })
hi('DiagnosticOk', { fg = p.cyan })

hi('DiagnosticUnderlineError', { undercurl = true, sp = p.red })
hi('DiagnosticUnderlineWarn', { undercurl = true, sp = p.yellow })
hi('DiagnosticUnderlineInfo', { undercurl = true, sp = p.cool })
hi('DiagnosticUnderlineHint', { undercurl = true, sp = p.subtle })

hi('QuickFixLine', { fg = p.fg, bg = p.surface, bold = true })
-----------------------------------------------------------------------
-- Diff / Git
-----------------------------------------------------------------------
hi('DiffAdd', { fg = p.cyan })
hi('DiffChange', { fg = p.amber })
hi('DiffDelete', { fg = p.red })
hi('DiffText', { fg = p.fg, bold = true })

hi('GitSignsAdd', { fg = p.cyan })
hi('GitSignsChange', { fg = p.amber })
hi('GitSignsDelete', { fg = p.red })

-----------------------------------------------------------------------
-- Telescope (if you use it)
-----------------------------------------------------------------------
hi('TelescopeNormal', { fg = p.fg, bg = p.surface })
hi('TelescopeBorder', { fg = p.overlay, bg = p.surface })
hi('TelescopeSelection', { fg = p.fg, bg = p.overlay })
hi('TelescopeMatching', { fg = p.cool, bold = true })

-----------------------------------------------------------------------
-- Treesitter (links to keep it simple)
-----------------------------------------------------------------------
link('@comment', 'Comment')
link('@string', 'String')
link('@character', 'Character')
link('@number', 'Number')
link('@float', 'Float')
link('@boolean', 'Boolean')
link('@constant', 'Constant')
hi('@constant.builtin', { fg = p.dim })

link('@function', 'Function')
hi('@function.call', { fg = p.cyan })
hi('@function.builtin', { fg = p.cyan })
hi('@method', { fg = p.cyan })

hi('@variable', { fg = p.fg })
hi('@variable.builtin', { fg = p.dim })
hi('@field', { fg = p.fg })
hi('@property', { fg = p.fg })
hi('@parameter', { fg = p.dim })

link('@type', 'Type')
hi('@type.builtin', { fg = p.cool })
hi('@type.qualifier', { fg = p.subtle })

hi('@keyword', { fg = p.amber })
hi('@keyword.function', { fg = p.amber })
hi('@keyword.return', { fg = p.amber })

hi('@operator', { fg = p.subtle })

hi('@punctuation', { fg = p.subtle })
hi('@punctuation.bracket', { fg = p.subtle })
hi('@punctuation.delimiter', { fg = p.subtle })

hi('@tag', { fg = p.dim })
hi('@attribute', { fg = p.dim })

-----------------------------------------------------------------------
-- Optional yank highlight
-----------------------------------------------------------------------
hi('YankHighlight', { fg = p.bg, bg = p.dim, bold = true })
