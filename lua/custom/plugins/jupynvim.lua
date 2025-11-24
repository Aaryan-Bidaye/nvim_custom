return {
  {
    dir = '~/.config/nvim/lua/jupynvim/', -- or your repo path
    config = function()
      local jt = require 'jupynvim'
      local ipynb = require 'jupynvim.ipynb'
      jt.setup()
      ipynb.setup {
        send = function(cells)
          jt.start()
          jt.send(cells)
        end,
      }
    end,
  },
}
