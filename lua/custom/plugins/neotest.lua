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
    {
      '<leader>ts',
      function()
        vim.cmd [[Neotest summary]]
      end,
      desc = 'Neotest toggle summary',
    },
    {
      '<leader>tp',
      function()
        require('neotest').output_panel.toggle()
      end,
      desc = 'Neotest output_panel toggle',
    },
    {
      '<leader>tt',
      function()
        vim.cmd [[Neotest run]]
      end,
      desc = 'Neotest nearest',
    },
    {
      '<leader>tf',
      function()
        require('neotest').run.run(vim.fn.expand '%')
      end,
      desc = 'Neotest file',
    },
    {
      '<leader>ta',
      function()
        vim.cmd [[Neotest attach]]
      end,
      desc = 'Neotest attach',
    },
    {
      '<leader>tww',
      function()
        require('neotest').watch.watch {}
      end,
      desc = 'Run Watch file',
    },
    {
      '<leader>twr',
      function()
        require('neotest').run.run { vitestCommand = 'vitest --watch' }
      end,
      desc = 'Run Watch',
    },
    {
      '<leader>twf',
      function()
        require('neotest').run.run { vim.fn.expand '%', vitestCommand = 'vitest --watch' }
      end,
      desc = 'Run Watch File',
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
