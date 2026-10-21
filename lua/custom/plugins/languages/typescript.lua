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

            -- vtsls: prefer the monorepo/workspace root over the nearest nested package.
            -- The shipped nvim-lspconfig root_dir only looks for lock files and .git, and
            -- Neovim ignores root_markers whenever root_dir is set, so it must be replaced.
            ---@param name string
            ---@param dir string
            ---@return boolean
            local has_workspaces = function(name, dir)
              if name ~= 'package.json' then
                return false
              end
              local file = io.open(vim.fs.joinpath(dir, name), 'r')
              if not file then
                return false
              end
              local content = file:read '*a'
              file:close()
              if not content then
                return false
              end
              local ok, decoded = pcall(vim.json.decode, content)
              return ok and type(decoded) == 'table' and type(decoded.workspaces) == 'table'
            end

            ---@type (string|fun(name: string, path: string): boolean)[]
            local workspace_markers = { 'pnpm-workspace.yaml', 'turbo.json', 'nx.json', 'lerna.json', 'rush.json', has_workspaces }

            vim.lsp.config('vtsls', {
              root_dir = function(bufnr, on_dir)
                -- Deno buffers are owned by denols; do not attach vtsls.
                if vim.fs.root(bufnr, { 'deno.json', 'deno.jsonc' }) then
                  return
                end
                local root = vim.fs.root(bufnr, workspace_markers)
                  or vim.fs.root(bufnr, { 'pnpm-lock.yaml', 'package-lock.json', 'yarn.lock', 'bun.lockb', 'bun.lock' })
                  or vim.fs.root(bufnr, { '.git' })
                  or vim.fs.root(bufnr, { 'tsconfig.json', 'jsconfig.json' })
                  or vim.fn.getcwd()
                on_dir(root)
              end,
            })
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
