return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      {
        'Sebastian-Nielsen/better-type-hover',
        ft = { 'typescript', 'typescriptreact' },
        config = function()
          require('better-type-hover').setup {
            openTypeDocKeymap = 'K',
          }
        end,
      },
    },
    opts = {
      -- make sure mason installs the server
      servers = {
        vtsls = {
          -- explicitly add default filetypes, so that we can extend
          -- them in related extras
          filetypes = {
            'javascript',
            'javascriptreact',
            'javascript.jsx',
            'typescript',
            'typescriptreact',
            'typescript.tsx',
          },
          settings = {
            complete_function_calls = true,
            vtsls = {
              enableMoveToFileCodeAction = true,
              autoUseWorkspaceTsdk = true,
              experimental = {
                maxInlayHintLength = 30,
                completion = {
                  enableServerSideFuzzyMatch = true,
                },
              },
            },
            typescript = {
              updateImportsOnFileMove = { enabled = 'always' },
              suggest = {
                completeFunctionCalls = true,
              },
              inlayHints = {
                enumMemberValues = { enabled = true },
                functionLikeReturnTypes = { enabled = true },
                parameterNames = { enabled = 'literals' },
                parameterTypes = { enabled = true },
                propertyDeclarationTypes = { enabled = true },
                variableTypes = { enabled = false },
              },
            },
          },
          keys = {},
        },
      },
      setup = {
        vtsls = function(_, opts)
          if vim.lsp.config.denols and vim.lsp.config.vtsls then
            ---@param server string
            local resolve = function(server)
              local markers, root_dir = vim.lsp.config[server].root_markers, vim.lsp.config[server].root_dir
              vim.lsp.config(server, {
                root_dir = function(bufnr, on_dir)
                  local is_deno = vim.fs.root(bufnr, { 'deno.json', 'deno.jsonc' }) ~= nil
                  if is_deno == (server == 'denols') then
                    if root_dir then
                      return root_dir(bufnr, on_dir)
                    elseif type(markers) == 'table' then
                      local root = vim.fs.root(bufnr, markers)
                      return root and on_dir(root)
                    end
                  end
                end,
              })
            end
            resolve 'denols'
            resolve 'vtsls'
          end

          -- TODO: This isn't working, the command exists but it's not triggering
          Snacks.util.lsp.on({ name = 'vtsls' }, function(buffer, client)
            client.commands['_typescript.moveToFileRefactoring'] = function(command, ctx)
              ---@type string, string, lsp.Range
              local action, uri, range = unpack(command.arguments)

              local function move(newf)
                client:request('workspace/executeCommand', {
                  command = command.command,
                  arguments = { action, uri, range, newf },
                })
              end

              local fname = vim.uri_to_fname(uri)
              client:request('workspace/executeCommand', {
                command = 'typescript.tsserverRequest',
                arguments = {
                  'getMoveToRefactoringFileSuggestions',
                  {
                    file = fname,
                    startLine = range.start.line + 1,
                    startOffset = range.start.character + 1,
                    endLine = range['end'].line + 1,
                    endOffset = range['end'].character + 1,
                  },
                },
              }, function(_, result)
                ---@type string[]
                local files = result.body.files
                table.insert(files, 1, 'Enter new path...')
                vim.ui.select(files, {
                  prompt = 'Select move destination:',
                  format_item = function(f)
                    return vim.fn.fnamemodify(f, ':~:.')
                  end,
                }, function(f)
                  if f and f:find '^Enter new path' then
                    vim.ui.input({
                      prompt = 'Enter move destination:',
                      default = vim.fn.fnamemodify(fname, ':h') .. '/',
                      completion = 'file',
                    }, function(newf)
                      return newf and move(newf)
                    end)
                  elseif f then
                    move(f)
                  end
                end)
              end)
            end
          end)
          -- copy typescript settings to javascript
          opts.settings.javascript = vim.tbl_deep_extend('force', {}, opts.settings.typescript, opts.settings.javascript or {})
        end,
      },
    },
  },
}
