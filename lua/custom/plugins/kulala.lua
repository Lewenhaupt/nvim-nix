local kulala_prefix = '<leader>r'
return {
  'mistweaverco/kulala.nvim',
  ft = { 'http', 'rest' },
  opts = {
    global_keymaps = true,
    global_keymaps_prefix = kulala_prefix,
    kulala_keymaps_prefix = '',
  },
  keys = {
    {
      kulala_prefix .. 'e',
      function()
        require('kulala').set_selected_env()
      end,
      desc = 'Select [E]nvironment',
    },
  },
}
