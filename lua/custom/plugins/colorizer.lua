return {
  {
    'NvChad/nvim-colorizer.lua',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      require('colorizer').setup {
        filetypes = { '*' },
        user_default_options = {
          RGB = true,
          RRGGBB = true,
          RRGGBBAA = true,
          names = false,
          mode = 'background', -- or "foreground"/"virtualtext" if you prefer
        },
      }
    end,
  },
}
