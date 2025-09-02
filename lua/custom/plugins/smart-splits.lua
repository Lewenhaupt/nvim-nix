return {
  'mrjones2014/smart-splits.nvim',
  lazy = false,
  keys = {
    -- Resize
    {
      '<leader>srh',
      function()
        require('smart-splits').resize_left()
      end,
      mode = 'n',
      desc = 'Resize Left',
    },
    {
      '<leader>srj',
      function()
        require('smart-splits').resize_down()
      end,
      mode = 'n',
      desc = 'Resize Down',
    },
    {
      '<leader>srk',
      function()
        require('smart-splits').resize_up()
      end,
      mode = 'n',
      desc = 'Resize Up',
    },
    {
      '<leader>srl',
      function()
        require('smart-splits').resize_right()
      end,
      mode = 'n',
      desc = 'Resize Right',
    },
    -- Move
    {
      '<leader>sh',
      function()
        require('smart-splits').move_cursor_left()
      end,
      mode = 'n',
      desc = 'Move Left',
    },
    {
      '<leader>sj',
      function()
        require('smart-splits').move_cursor_down()
      end,
      mode = 'n',
      desc = 'Move Down',
    },
    {
      '<leader>sk',
      function()
        require('smart-splits').move_cursor_up()
      end,
      mode = 'n',
      desc = 'Move Up',
    },
    {
      '<leader>sl',
      function()
        require('smart-splits').move_cursor_right()
      end,
      mode = 'n',
      desc = 'Move Right',
    },
    -- Swap
    {
      '<leader>ssh',
      function()
        require('smart-splits').swap_buf_left()
      end,
      mode = 'n',
      desc = 'Swap Left',
    },
    {
      '<leader>ssj',
      function()
        require('smart-splits').swap_buf_down()
      end,
      mode = 'n',
      desc = 'Swap Down',
    },
    {
      '<leader>ssk',
      function()
        require('smart-splits').swap_buf_up()
      end,
      mode = 'n',
      desc = 'Swap Up',
    },
    {
      '<leader>ssl',
      function()
        require('smart-splits').swap_buf_right()
      end,
      mode = 'n',
      desc = 'Swap Right',
    },
  },
}
