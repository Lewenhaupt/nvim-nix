--- Highest-installed / declared TypeScript major for a project root.
---@param root string|nil
---@return integer|nil
local function project_ts_major(root)
  if not root then
    return nil
  end

  -- 1. The installed compiler is what the project actually builds with.
  local f = io.open(vim.fs.joinpath(root, 'node_modules/typescript/package.json'), 'r')
  if f then
    local content = f:read '*a'
    f:close()
    local ok, decoded = pcall(vim.json.decode, content or '')
    if ok and type(decoded) == 'table' and type(decoded.version) == 'string' then
      local version = vim.version.parse(decoded.version)
      if version then
        return version.major
      end
    end
  end

  -- 2. Declared range, e.g. "^5.9.3" / "~7.0.0" / ">=6".
  f = io.open(vim.fs.joinpath(root, 'package.json'), 'r')
  if f then
    local content = f:read '*a'
    f:close()
    local ok, decoded = pcall(vim.json.decode, content or '')
    if ok and type(decoded) == 'table' then
      for _, field in ipairs { 'devDependencies', 'dependencies', 'peerDependencies', 'optionalDependencies' } do
        local range = type(decoded[field]) == 'table' and decoded[field].typescript
        local digits = type(range) == 'string' and range:match '%d+'
        if digits then
          return tonumber(digits)
        end
      end
    end
  end

  return nil
end

--- First binary that is really TypeScript 7's native compiler (`--lsp` capable).
--- Mirrors nvim-lspconfig's own probe, so the two agree on which projects are served.
---@param root string
---@return string|nil
local function ts7_binary(root)
  local candidates = {
    vim.fs.joinpath(root, 'node_modules/.bin/tsc'),
    vim.fs.joinpath(root, 'node_modules/.bin/tsgo'),
    'tsc',
    'tsgo',
  }
  for _, bin in ipairs(candidates) do
    if vim.fn.executable(bin) == 1 then
      local out = vim.system({ bin, '--version' }, { text = true }):wait()
      local version = vim.version.parse(out.stdout or '')
      if out.code == 0 and version ~= nil and version.major >= 7 then
        return bin
      end
    end
  end
  return nil
end

--- tsgo owns the project unless it is pinned to TypeScript < 6 (or forced).
---@param root string
---@return boolean
local function tsgo_should_own(root)
  if vim.g.ts_lsp_force_vtsls then
    return false
  end
  if vim.g.ts_lsp_force_tsgo then
    return true
  end
  local major = project_ts_major(root)
  return major == nil or major >= 6
end

local ts_filetypes = {
  'javascript',
  'javascriptreact',
  'javascript.jsx',
  'typescript',
  'typescriptreact',
  'typescript.tsx',
}

-- Shared by `tsc` and `vtsls`; tsgo ignores the vtsls-only keys.
local settings = {
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
}

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
        -- tsgo (TypeScript 7 native tsc --lsp); vtsls is the TS 5.x fallback.
        -- Selection happens in setup.tsc/setup.vtsls below.
        tsc = {
          filetypes = ts_filetypes,
          settings = settings,
        },
        vtsls = {
          filetypes = ts_filetypes,
          settings = settings,
        },
      },
      setup = {
        tsc = function(_, opts)
          -- tsgo pulls `js/ts` and merges it per key on top of `typescript`/`javascript`,
          -- and lspconfig seeds `js/ts` with every inlay hint plus both code lens kinds on.
          -- The narrowed values must be written into `js/ts` or they are lost.
          local js_ts = {
            inlayHints = {
              enumMemberValues = { enabled = true },
              functionLikeReturnTypes = { enabled = true },
              parameterNames = { enabled = 'literals', suppressWhenArgumentMatchesName = true },
              parameterTypes = { enabled = true },
              propertyDeclarationTypes = { enabled = true },
              variableTypes = { enabled = false },
            },
            referencesCodeLens = { enabled = false },
            implementationsCodeLens = { enabled = false },
          }
          -- Copy so the shared settings table stays vtsls-only.
          local existing_js_ts = (opts.settings or {})['js/ts'] or {}
          opts.settings = vim.tbl_deep_extend('force', {}, opts.settings or {})
          opts.settings['js/ts'] = vim.tbl_deep_extend('force', js_ts, existing_js_ts)

          -- Gate first, then delegate to the shipped resolver so its TS 7 probe,
          -- deno refusal, bin cache and "no TS 7 binary" notification stay authoritative.
          local shipped_root_dir = (vim.lsp.config.tsc or {}).root_dir
          vim.lsp.config('tsc', {
            root_dir = function(bufnr, on_dir)
              local root = vim.fs.root(bufnr, { 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb', 'bun.lock', '.git' }) or vim.fn.getcwd()
              if not tsgo_should_own(root) then
                return -- TS 5 project: vtsls owns it
              end
              if shipped_root_dir then
                return shipped_root_dir(bufnr, on_dir)
              end
              on_dir(root)
            end,
          })
        end,
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

            ---@param bufnr integer
            ---@return string
            local monorepo_root = function(bufnr)
              return vim.fs.root(bufnr, workspace_markers)
                or vim.fs.root(bufnr, { 'pnpm-lock.yaml', 'package-lock.json', 'yarn.lock', 'bun.lockb', 'bun.lock' })
                or vim.fs.root(bufnr, { '.git' })
                or vim.fs.root(bufnr, { 'tsconfig.json', 'jsconfig.json' })
                or vim.fn.getcwd()
            end

            vim.lsp.config('vtsls', {
              root_dir = function(bufnr, on_dir)
                -- Deno buffers are owned by denols; do not attach vtsls.
                if vim.fs.root(bufnr, { 'deno.json', 'deno.jsonc' }) then
                  return
                end
                local root = monorepo_root(bufnr)
                -- tsgo owns this project when it is not pinned to TS < 6 and a
                -- TS 7 `--lsp` binary actually exists; never attach both servers.
                if tsgo_should_own(root) and ts7_binary(root) ~= nil then
                  return
                end
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
                if not (result and result.body and result.body.files) then
                  return vim.notify('move-to-file: no suggestions from vtsls', vim.log.levels.WARN)
                end
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
