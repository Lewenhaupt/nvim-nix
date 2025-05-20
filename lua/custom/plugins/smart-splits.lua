return {
  'mrjones2014/smart-splits.nvim',
  lazy = false,
  config = function()
    vim.keymap.set('n', '<M-S-h>', require('smart-splits').resize_left)
    vim.keymap.set('n', '<M-S-j>', require('smart-splits').resize_down)
    vim.keymap.set('n', '<M-S-k>', require('smart-splits').resize_up)
    vim.keymap.set('n', '<M-S-l>', require('smart-splits').resize_right)
    -- moving between splits
    vim.keymap.set('n', '<M-h>', require('smart-splits').move_cursor_left)
    vim.keymap.set('n', '<M-j>', require('smart-splits').move_cursor_down)
    vim.keymap.set('n', '<M-k>', require('smart-splits').move_cursor_up)
    vim.keymap.set('n', '<M-l>', require('smart-splits').move_cursor_right)
    -- swapping buffers between windows
    vim.keymap.set('n', '<leader>sh', require('smart-splits').swap_buf_left)
    vim.keymap.set('n', '<leader>sj', require('smart-splits').swap_buf_down)
    vim.keymap.set('n', '<leader>sk', require('smart-splits').swap_buf_up)
    vim.keymap.set('n', '<leader>sl', require('smart-splits').swap_buf_right)
  end,
}
