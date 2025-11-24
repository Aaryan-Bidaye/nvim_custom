return {
  {
    'zbirenbaum/copilot.lua',
    event = 'InsertEnter',
    config = function()
      require('copilot').setup {
        suggestion = { enabled = false }, -- turn OFF inline ghost text
        panel = { enabled = false }, -- turn OFF side panel
      }
    end,
  },

  {
    'fang2hou/blink-copilot',
    dependencies = { 'saghen/blink.cmp', 'zbirenbaum/copilot.lua' },
  },
}
