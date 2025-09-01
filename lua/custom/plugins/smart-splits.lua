return {
  'mrjones2014/smart-splits.nvim',
  lazy = false,
  keys = {
    -- Resize
    { '<leader>srh', require('smart-splits').resize_left, mode = 'n', desc = 'Resize Left' },
    { '<leader>srj', require('smart-splits').resize_down, mode = 'n', desc = 'Resize Down' },
    { '<leader>srk', require('smart-splits').resize_up, mode = 'n', desc = 'Resize Up' },
    { '<leader>srl', require('smart-splits').resize_right, mode = 'n', desc = 'Resize Right' },
    -- Move
    { '<leader>sh', require('smart-splits').move_cursor_left, mode = 'n', desc = 'Move Left' },
    { '<leader>sj', require('smart-splits').move_cursor_down, mode = 'n', desc = 'Move Down' },
    { '<leader>sk', require('smart-splits').move_cursor_up, mode = 'n', desc = 'Move Up' },
    { '<leader>sl', require('smart-splits').move_cursor_right, mode = 'n', desc = 'Move Right' },
    -- Swap
    { '<leader>ssh', require('smart-splits').swap_buf_left, mode = 'n', desc = 'Swap Left' },
    { '<leader>ssj', require('smart-splits').swap_buf_down, mode = 'n', desc = 'Swap Down' },
    { '<leader>ssk', require('smart-splits').swap_buf_up, mode = 'n', desc = 'Swap Up' },
    { '<leader>ssl', require('smart-splits').swap_buf_right, mode = 'n', desc = 'Swap Right' },
  },
}
