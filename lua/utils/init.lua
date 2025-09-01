local M = {}

M.nocode = function()
  return vim.fn.exists 'g:vscode' == 0
end

return M
