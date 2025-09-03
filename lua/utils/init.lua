local M = {}

M.nocode = function()
  return vim.fn.exists 'g:vscode' == 0
end

M.nowork = function()
  return os.getenv 'IS_WORK' == 'Y'
end

return M
