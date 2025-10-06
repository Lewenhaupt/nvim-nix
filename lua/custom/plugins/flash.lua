return {
  'folke/flash.nvim',
  event = 'VeryLazy',
  ---@type Flash.Config
  opts = {
    modes = {
      search = {
        enabled = true,
      },
    },
  },
  -- stylua: ignore
  keys = {
    { "gs", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    { "gf", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    { "gF", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    { "gS", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
  },
}
