return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-neotest/neotest-python',
    'nvim-neotest/neotest-plenary',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',
    { 'fredrikaverpil/neotest-golang', version = '*' },
    'marilari88/neotest-vitest',
    'mrcjkb/rustaceanvim',
  },
  keys = {
    {
      '<leader>td',
      function()
        require('neotest').run.run { suite = false, strategy = 'dap' }
      end,
      desc = 'Debug nearest test',
    },
  },
  config = function()
    require('neotest').setup {
      adapters = {
        require 'neotest-python' {
          dap = { justMyCode = false },
        },
        require 'neotest-plenary',
        require 'neotest-golang' {
          -- log_level = vim.log.levels.DEBUG,
          -- env = {
          --   CGO_ENABLED = '1',
          -- },
        },
        require 'neotest-vitest',
        require 'rustaceanvim.neotest',
      },
    }
  end,
}
