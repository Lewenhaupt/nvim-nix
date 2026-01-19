return {
  {
    'stevearc/oil.nvim',
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
      skip_confirm_for_simple_edits = true,
      view_options = {
        show_hidden = true,
      },
      keymaps = {
        ['<Leader>yy'] = { 'actions.yank_entry', opts = { modify = ':~:.' }, desc = '[Oil] Yank relative path' },
        ['<Leader>YY'] = { 'actions.yank_entry', desc = '[Oil] Yank absolute path' },
        ['<Leader>yf'] = { 'actions.yank_entry', opts = { modify = ':t' }, desc = '[Oil] Yank file name' },
      },
    },
    cond = require('utils.init').nocode,
    keys = {
      {
        '<leader>å',
        '<cmd>Oil<cr>',
        desc = 'Open oil here',
      },
    },
    -- Optional dependencies
    dependencies = { { 'echasnovski/mini.icons', opts = {} } },
    -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
    lazy = false,
  },
  {
    'JezerM/oil-lsp-diagnostics.nvim',
    dependencies = { 'stevearc/oil.nvim' },
    opts = {},
  },
}
