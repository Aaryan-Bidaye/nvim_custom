-- theme & transparency
vim.cmd.colorscheme 'unokai' -- Set colorscheme

vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' }) --set transparent for current buffer
vim.api.nvim_set_hl(0, 'NormalNC', { bg = 'none' }) --Set transparency for non current buffers
vim.api.nvim_set_hl(0, 'EndOfBuffer', { bg = 'none' }) --Set transparency for window past EOB

-- Transparent background for all floating/popup elements
local function set_transparent()
  local groups = {
    'Normal',
    'NormalNC',
    'NormalFloat',
    'SignColumn',
    'FloatBorder',
    'Pmenu',
    'TelescopeNormal',
    'TelescopeBorder',
    'TelescopePromptNormal',
    'TelescopePromptBorder',
    'TelescopeResultsNormal',
    'TelescopeResultsBorder',
    'TelescopePreviewNormal',
    'TelescopePreviewBorder',
    'WhichKeyNormal',
    'WhichKeyFloat',
    'LazyNormal',
    'MasonNormal',
    'OilNormal',
    'CmpPmenu',
  }

  for _, group in ipairs(groups) do
    vim.api.nvim_set_hl(0, group, { bg = 'none' })
  end
end

-- Run after colorscheme is applied (so the theme doesn't override it)
vim.api.nvim_create_autocmd('ColorScheme', {
  pattern = 'unokai',
  callback = function()
    local g = '#a6e22e'
    -- unify signs, diff, and lualine’s diff
    vim.api.nvim_set_hl(0, 'GitSignsAdd', { fg = g, bg = 'NONE' })
    vim.api.nvim_set_hl(0, 'Added', { fg = g, bg = 'NONE' })
    -- keep Unokai’s reverse style for DiffAdd, just swap the green
    local da = vim.api.nvim_get_hl(0, { name = 'DiffAdd', link = false }) or {}
    vim.api.nvim_set_hl(0, 'DiffAdd', { fg = g, bg = da.bg or 'NONE', reverse = da.reverse ~= nil and da.reverse or true })
    set_transparent()
  end,
})
-- apply immediately if theme already set
vim.cmd.hi 'clear' -- optional if you want a hard refresh
vim.cmd.colorscheme 'quieter' -- re-apply your theme
-- Apply immediately if theme already loaded
set_transparent()
