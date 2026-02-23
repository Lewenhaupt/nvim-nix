return {

  { -- Linting
    'mfussenegger/nvim-lint',
    -- NOTE: nixCats: return true only if category is enabled, else false
    enabled = require('nixCatsUtils').enableForCategory 'kickstart-lint',
    dependencies = {
      {
        'rshkarin/mason-nvim-lint',
        -- NOTE: nixCats: use lazyAdd to only enable mason if nix wasnt involved.
        -- because we will be using nix to download things instead.
        enabled = require('nixCatsUtils').lazyAdd(true, false),
        config = function()
          require('mason-nvim-lint').setup()
        end,
      },
    },
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      events = { 'BufWritePost', 'BufReadPost', 'InsertLeave' },
      linters_by_ft = {
        markdown = { 'markdownlint' },
        javascript = { 'biomejs' },
        javascriptreact = { 'biomejs' },
        typescript = { 'biomejs' },
        typescriptreact = { 'biomejs' },
        json = { 'biomejs', 'eslint_d' },
        jsonc = { 'biomejs', 'eslint_d' },
        go = { 'golangcilint' },
        rust = { 'clippy' },
      },
      ---@type table<string,table>
      linters = {
        biomejs = {
          condition = function(ctx)
            return vim.fs.find({ 'biome.json', 'biome.jsonc' }, { path = ctx.filename, upward = true })
          end,
        },
        eslint_d = {
          condition = function(ctx)
            return vim.fs.find({
              '.eslintrc.js',
              '.eslintrc.cjs',
              '.eslintrc.yaml',
              '.eslintrc.yml',
              '.eslintrc.json',
              'eslint.config.js',
              'eslint.config.cjs',
              'eslint.config.mjs',
              'eslint.config.ts',
              'eslint.config.mts',
              'eslint.config.cts',
            }, { path = ctx.filename, upward = true })
          end,
        },
      },
    },
    config = function(_, opts)
      local M = {}

      local lint = require 'lint'
      for name, linter in pairs(opts.linters) do
        if type(linter) == 'table' and type(lint.linters[name]) == 'table' then
          lint.linters[name] = vim.tbl_deep_extend('force', lint.linters[name], linter)
          if type(linter.prepend_args) == 'table' then
            lint.linters[name].args = lint.linters[name].args or {}
            vim.list_extend(lint.linters[name].args, linter.prepend_args)
          end
        else
          lint.linters[name] = linter
        end
      end
      lint.linters_by_ft = opts.linters_by_ft

      function M.debounce(ms, fn)
        local timer = vim.uv.new_timer()
        return function(...)
          local argv = { ... }
          timer:start(ms, 0, function()
            timer:stop()
            vim.schedule_wrap(fn)(unpack(argv))
          end)
        end
      end

      function M.lint()
        -- Use nvim-lint's logic first:
        -- * checks if linters exist for the full filetype first
        -- * otherwise will split filetype by "." and add all those linters
        -- * this differs from conform.nvim which only uses the first filetype that has a formatter
        local names = lint._resolve_linter_by_ft(vim.bo.filetype)

        -- Create a copy of the names table to avoid modifying the original.
        names = vim.list_extend({}, names)

        -- Add fallback linters.
        if #names == 0 then
          vim.list_extend(names, lint.linters_by_ft['_'] or {})
        end

        -- Add global linters.
        vim.list_extend(names, lint.linters_by_ft['*'] or {})

        -- Filter out linters that don't exist or don't match the condition.
        local ctx = { filename = vim.api.nvim_buf_get_name(0) }
        ctx.dirname = vim.fn.fnamemodify(ctx.filename, ':h')
        names = vim.tbl_filter(function(name)
          local linter = lint.linters[name]
          if not linter then
            print('Linter not found: ' .. name, { title = 'nvim-lint' })
          end
          return linter and not (type(linter) == 'table' and linter.condition and not linter.condition(ctx))
        end, names)

        local lint_opts = {}

        local clients = vim.lsp.get_clients { bufnr = 0 }
        local key, client = next(clients)
        while key do
          if client.workspace_folders then
            for _, dir in pairs(client.workspace_folders) do
              if vim.fs.relpath(dir.name, vim.api.nvim_buf_get_name(0)) then
                lint_opts.cwd = dir.name
              end
            end
          elseif client.root_dir then
            lint_opts.cwd = client.root_dir
          end
          if lint_opts.cwd then
            break
          end
          key, client = next(clients, key)
        end

        -- Run linters.
        if #names > 0 then
          lint.try_lint(names, lint_opts)
        end
      end

      vim.api.nvim_create_autocmd(opts.events, {
        group = vim.api.nvim_create_augroup('nvim-lint', { clear = true }),
        callback = M.debounce(100, M.lint),
      })
    end,
  },
}
