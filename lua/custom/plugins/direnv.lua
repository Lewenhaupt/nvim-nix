return {
  'NotAShelf/direnv.nvim',
  config = function()
    require('direnv').setup {
      -- Whether to automatically load direnv when entering a directory with .envrc
      autoload_direnv = true,
      -- Statusline integration
      statusline = {
        -- Enable statusline component
        enabled = true,
        -- Icon to display in statusline
        icon = '󱚟',
      },
    }
  end,
}
