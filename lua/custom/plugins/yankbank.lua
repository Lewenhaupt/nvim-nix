return {
  'ptdewey/yankbank-nvim',
  dependencies = 'kkharji/sqlite.lua',
  config = function()
    require('yankbank').setup {
      persist_type = 'sqlite',
      db_path = vim.fn.stdpath 'data',
    }
  end,
  keys = {
    {
      '<leader>y',
      mode = { 'n' },
      '<cmd>YankBank<cr>',
      desc = 'YankBank',
    },
  },
}
