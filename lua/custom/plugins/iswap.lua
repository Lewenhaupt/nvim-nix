return {
  'mizlan/iswap.nvim',
  event = 'VeryLazy',
  keys = {
    {
      '<leader>is',
      mode = { 'n' },
      '<cmd>ISwapWith<CR>',
      desc = 'Swap With',
    },
    {
      '<leader>iS',
      mode = { 'n' },
      '<cmd>ISwapNodeWith<CR>',
      desc = 'Swap Node With',
    },
    {
      '<leader>im',
      mode = { 'n' },
      '<cmd>ISwapMove<CR>',
      desc = 'Move',
    },
    {
      '<leader>is',
      mode = { 'n' },
      '<cmd>ISwapNodeMove<CR>',
      desc = 'Move Node',
    },
  },
}
