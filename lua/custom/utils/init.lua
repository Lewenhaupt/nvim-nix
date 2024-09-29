local cmd = vim.api.nvim_create_user_command

cmd('ToggleInlayHints', function()
  if vim.lsp.inlay_hint.is_enabled { bufnr = 0 } then
    vim.lsp.inlay_hint.enable(false)
    return
  end
  vim.lsp.inlay_hint.enable(true)
end, {})

cmd('ToggleLspDiag', function()
  local buf_clients = vim.lsp.get_clients()
  if next(buf_clients) == nil then
    if type(buf_clients) == 'boolean' or #buf_clients == 0 then
      vim.notify 'No LSP client found'
      return
    end
  end
  if vim.g.diagnostics_visible then
    vim.g.diagnostics_visible = false
    vim.diagnostic.enable(false)
  else
    vim.g.diagnostics_visible = true
    vim.diagnostic.enable()
  end
end, {})

local M = {}

M.create_select_menu = function(prompt, options_table) -- Or M.create_select_menu = function(prompt, options_table)
  -- Given the table of options, populate a list with option display names
  local option_names = {}
  local n = 0
  for i, _ in pairs(options_table) do
    n = n + 1
    option_names[n] = i
  end
  table.sort(option_names)

  -- Return the prompt function. These global function var will be used when assigning keybindings
  local menu = function()
    vim.ui.select(
      option_names, --> the list we populated above
      {
        prompt = prompt, --> Prompt passed as the argument
        -- Remove this variable if you want to keep the numbering in front of option names
        format_item = function(item)
          return item:gsub('%d. ', '')
        end,
      },

      function(choice)
        local action = options_table[choice]
        -- When user inputs ESC or q, don't take any actions
        if action ~= nil then
          if type(action) == 'string' then
            vim.cmd(action)
          elseif type(action) == 'function' then
            action()
          end
        end
      end
    )
  end

  return menu
end

return M
