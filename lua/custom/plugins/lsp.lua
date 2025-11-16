local config = require 'custom.config'
return {
  -- lspconfig
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPost', 'BufNewFile', 'BufWritePre' },
    dependencies = {
      { 'mason-org/mason.nvim', enabled = require('nixCatsUtils').lazyAdd(true, false) },
      { 'mason-org/mason-lspconfig.nvim', enabled = require('nixCatsUtils').lazyAdd(true, false), config = function() end },
      {
        'WhoIsSethDaniel/mason-tool-installer.nvim',
        -- NOTE: nixCats: use lazyAdd to only enable mason if nix wasnt involved.
        -- because we will be using nix to download things instead.
        enabled = require('nixCatsUtils').lazyAdd(true, false),
      },
      { 'j-hui/fidget.nvim', opts = {} },
      { 'saghen/blink.cmp' },
      {
        'folke/lazydev.nvim',
        ft = 'lua',
        opts = {
          library = {
            -- adds type hints for nixCats global
            { path = (require('nixCats').nixCatsPath or '') .. '/lua', words = { 'nixCats' } },
          },
        },
      },
    },
    -- TODO: 'has' is not working yet
    keys = {

      {
        '<leader>cl',
        function()
          Snacks.picker.lsp_config()
        end,
        desc = 'Lsp Info',
      },
      {
        'gd',
        vim.lsp.buf.definition,
        desc = 'Goto Definition',
        -- has = 'definition'
      },
      { 'gr', vim.lsp.buf.references, desc = 'References', nowait = true },
      { 'gI', vim.lsp.buf.implementation, desc = 'Goto Implementation' },
      { 'gy', vim.lsp.buf.type_definition, desc = 'Goto T[y]pe Definition' },
      { 'gD', vim.lsp.buf.declaration, desc = 'Goto Declaration' },
      -- TODO: We currently set this in typescript.lua via better-type-hover, but ideally we should be able to set this one if that one doesn't exist
      -- {
      --   'K',
      --   function()
      --     return vim.lsp.buf.hover()
      --   end,
      --   desc = 'Hover',
      -- },
      {
        'gK',
        function()
          return vim.lsp.buf.signature_help()
        end,
        desc = 'Signature Help',
        -- has = 'signatureHelp',
      },
      {
        '<c-k>',
        function()
          return vim.lsp.buf.signature_help()
        end,
        mode = 'i',
        desc = 'Signature Help',
        -- has = 'signatureHelp',
      },
      {
        '<leader>ca',
        vim.lsp.buf.code_action,
        desc = 'Code Action',
        mode = { 'n', 'x', 'v' },
        -- has = 'codeAction'
      },
      {
        '<leader>cc',
        vim.lsp.codelens.run,
        desc = 'Run Codelens',
        mode = { 'n', 'x' },
        -- has = 'codeLens'
      },
      {
        '<leader>cC',
        vim.lsp.codelens.refresh,
        desc = 'Refresh & Display Codelens',
        mode = { 'n' },
        -- has = 'codeLens'
      },
      {
        '<leader>cR',
        function()
          Snacks.rename.rename_file()
        end,
        desc = 'Rename File',
        mode = { 'n' },
        -- has = { 'workspace/didRenameFiles', 'workspace/willRenameFiles' },
      },
      {
        '<leader>cr',
        vim.lsp.buf.rename,
        desc = 'Rename',
        -- has = 'rename'
      },
      -- { '<leader>cA', LazyVim.lsp.action.source, desc = 'Source Action', has = 'codeAction' },
      {
        ']]',
        function()
          Snacks.words.jump(vim.v.count1)
        end,
        -- has = 'documentHighlight',
        desc = 'Next Reference',
        -- enabled = function()
        --   return Snacks.words.is_enabled()
        -- end,
      },
      {
        '[[',
        function()
          Snacks.words.jump(-vim.v.count1)
        end,
        -- has = 'documentHighlight',
        desc = 'Prev Reference',
        -- enabled = function()
        --   return Snacks.words.is_enabled()
        -- end,
      },
      {
        '<a-n>',
        function()
          Snacks.words.jump(vim.v.count1, true)
        end,
        -- has = 'documentHighlight',
        desc = 'Next Reference',
        -- enabled = function()
        --   return Snacks.words.is_enabled()
        -- end,
      },
      {
        '<a-p>',
        function()
          Snacks.words.jump(-vim.v.count1, true)
        end,
        -- has = 'documentHighlight',
        desc = 'Prev Reference',
        -- enabled = function()
        --   return Snacks.words.is_enabled()
        -- end,
      },
    },
    opts_extend = { 'servers.*.keys' },
    opts = function()
      ---@class PluginLspOpts
      local ret = {
        -- options for vim.diagnostic.config()
        ---@type vim.diagnostic.Opts
        diagnostics = {
          underline = true,
          update_in_insert = false,
          virtual_text = {
            spacing = 4,
            source = 'if_many',
            prefix = '●',
            -- this will set set the prefix to a function that returns the diagnostics icon based on the severity
            -- prefix = "icons",
          },
          severity_sort = true,
          signs = {
            text = {
              [vim.diagnostic.severity.ERROR] = config.icons.diagnostics.Error,
              [vim.diagnostic.severity.WARN] = config.icons.diagnostics.Warn,
              [vim.diagnostic.severity.HINT] = config.icons.diagnostics.Hint,
              [vim.diagnostic.severity.INFO] = config.icons.diagnostics.Info,
            },
          },
        },
        -- Enable this to enable the builtin LSP inlay hints on Neovim.
        -- Be aware that you also will need to properly configure your LSP server to
        -- provide the inlay hints.
        inlay_hints = {
          enabled = true,
          exclude = { 'vue' }, -- filetypes for which you don't want to enable inlay hints
        },
        -- Enable this to enable the builtin LSP code lenses on Neovim.
        -- Be aware that you also will need to properly configure your LSP server to
        -- provide the code lenses.
        codelens = {
          enabled = false,
        },
        -- Enable this to enable the builtin LSP folding on Neovim.
        -- Be aware that you also will need to properly configure your LSP server to
        -- provide the folds.
        folds = {
          enabled = true,
        },
        -- options for vim.lsp.buf.format
        -- `bufnr` and `filter` is handled by the LazyVim formatter,
        -- but can be also overridden when specified
        format = {
          formatting_options = nil,
          timeout_ms = nil,
        },
        -- LSP Server Settings
        -- Sets the default configuration for an LSP client (or all clients if the special name "*" is used).
        servers = {
          -- configuration for all lsp servers
          ['*'] = {
            capabilities = {
              workspace = {
                fileOperations = {
                  didRename = true,
                  willRename = true,
                },
              },
            },
            -- stylua: ignore
            keys = {},
          },
          stylua = { enabled = false },
          lua_ls = {
            -- mason = false, -- set to false if you don't want this server to be installed with mason
            -- Use this to add any additional keymaps
            -- for specific lsp servers
            -- keys = {},
            mason = not require('nixCatsUtils').isNixCats,
            settings = {
              Lua = {
                workspace = {
                  checkThirdParty = false,
                },
                codeLens = {
                  enable = true,
                },
                completion = {
                  callSnippet = 'Replace',
                },
                doc = {
                  privateName = { '^_' },
                },
                diagnostics = {
                  globals = { 'nixCats' },
                  disable = { 'missing-fields' },
                },
                hint = {
                  enable = true,
                  setType = false,
                  paramType = true,
                  paramName = 'Disable',
                  semicolon = 'Disable',
                  arrayIndex = 'Disable',
                },
              },
            },
          },
        },
        nixd = {
          enabled = require('nixCatsUtils').isNixCats,
          mason = not require('nixCatsUtils').isNixCats,
        },
        eslint = {
          mason = not require('nixCatsUtils').isNixCats,
        },
        biome = {
          mason = not require('nixCatsUtils').isNixCats,
        },
        gopls = {
          mason = not require('nixCatsUtils').isNixCats,
          enabled = require('utils.init').nowork(),
        },
        pyright = {
          mason = not require('nixCatsUtils').isNixCats,
          enabled = require('utils.init').nowork(),
        },
        rust_analyzer = {
          mason = not require('nixCatsUtils').isNixCats,
          enabled = require('utils.init').nowork(),
        },

        -- you can do any additional lsp server setup here
        -- return true if you don't want this server to be setup with lspconfig
        ---@type table<string, fun(server:string, opts: vim.lsp.Config):boolean?>
        setup = {
          -- example to setup with typescript.nvim
          -- tsserver = function(_, opts)
          --   require("typescript").setup({ server = opts })
          --   return true
          -- end,
          -- Specify * to use this function as a fallback for any server
          -- ["*"] = function(server, opts) end,
        },
      }
      return ret
    end,
    ---@param opts PluginLspOpts
    config = vim.schedule_wrap(function(_, opts)
      -- setup autoformat
      --  TODO: See if we need this, we do use conform though
      -- LazyVim.format.register(LazyVim.lsp.formatter())

      -- setup keymaps
      -- TODO: Need to fix this if we want to customize keys for each lsp
      -- for server, server_opts in pairs(opts.servers) do
      --   if type(server_opts) == 'table' and server_opts.keys then
      --     require('lazyvim.plugins.lsp.keymaps').set({ name = server ~= '*' and server or nil }, server_opts.keys)
      --   end
      -- end

      -- inlay hints
      -- TODO: Not sure I want this enabled all the time
      -- if opts.inlay_hints.enabled then
      --   Snacks.util.lsp.on({ method = 'textDocument/inlayHint' }, function(buffer)
      --     if vim.api.nvim_buf_is_valid(buffer) and vim.bo[buffer].buftype == '' and not vim.tbl_contains(opts.inlay_hints.exclude, vim.bo[buffer].filetype) then
      --       vim.lsp.inlay_hint.enable(true, { bufnr = buffer })
      --     end
      --   end)
      -- end

      -- folds
      -- TODO: Fix this
      -- if opts.folds.enabled then
      --   Snacks.util.lsp.on({ method = 'textDocument/foldingRange' }, function()
      --     if LazyVim.set_default('foldmethod', 'expr') then
      --       LazyVim.set_default('foldexpr', 'v:lua.vim.lsp.foldexpr()')
      --     end
      --   end)
      -- end

      -- code lens
      if opts.codelens.enabled and vim.lsp.codelens then
        Snacks.util.lsp.on({ method = 'textDocument/codeLens' }, function(buffer)
          vim.lsp.codelens.refresh()
          vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'InsertLeave' }, {
            buffer = buffer,
            callback = vim.lsp.codelens.refresh,
          })
        end)
      end

      -- diagnostics
      if type(opts.diagnostics.virtual_text) == 'table' and opts.diagnostics.virtual_text.prefix == 'icons' then
        opts.diagnostics.virtual_text.prefix = function(diagnostic)
          local icons = config.icons.diagnostics
          for d, icon in pairs(icons) do
            if diagnostic.severity == vim.diagnostic.severity[d:upper()] then
              return icon
            end
          end
          return '●'
        end
      end
      vim.diagnostic.config(vim.deepcopy(opts.diagnostics))

      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, modes)
            vim.keymap.set(modes or 'n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client.server_capabilities.documentHighlightProvider then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following autocommand is used to enable inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      if opts.servers['*'] then
        vim.lsp.config('*', opts.servers['*'])
      end

      -- get all the servers that are available through mason-lspconfig
      local have_mason = not require('nixCatsUtils').isNixCats
      local mason_all = have_mason and vim.tbl_keys(require('mason-lspconfig.mappings').get_mason_map().lspconfig_to_package) or {} --[[ @as string[] ]]
      local mason_exclude = {} ---@type string[]

      ---@return boolean? exclude automatic setup
      local function configure(server)
        if server == '*' then
          return false
        end
        local sopts = opts.servers[server]
        sopts = sopts == true and {} or (not sopts) and { enabled = false } or sopts --[[@as vim.lsp.Config]]

        ---@diagnostic disable-next-line: undefined-field
        if sopts.enabled == false then
          mason_exclude[#mason_exclude + 1] = server
          return
        end

        ---@diagnostic disable-next-line: undefined-field
        local use_mason = sopts.mason ~= false and vim.tbl_contains(mason_all, server)
        local setup = opts.setup[server] or opts.setup['*']
        if setup and setup(server, sopts) then
          mason_exclude[#mason_exclude + 1] = server
        else
          vim.lsp.config(server, sopts) -- configure the server
          if not use_mason then
            vim.lsp.enable(server)
          end
        end
        return use_mason
      end

      local install = vim.tbl_filter(configure, vim.tbl_keys(opts.servers))
      if have_mason then
        require('mason-lspconfig').setup {
          ensure_installed = install,
          automatic_enable = { exclude = mason_exclude },
        }
        require('mason-tool-installer').setup {
          ensure_installed = install,
        }
      end
    end),
  },

  -- cmdline tools and lsp servers
  {

    'mason-org/mason.nvim',
    cmd = 'Mason',
    keys = { { '<leader>cm', '<cmd>Mason<cr>', desc = 'Mason' } },
    build = ':MasonUpdate',
    enabled = not require('nixCatsUtils').isNixCats,
    opts_extend = { 'ensure_installed' },
    opts = {
      ensure_installed = {
        'stylua',
        'shfmt',
      },
    },
    ---@param opts MasonSettings | {ensure_installed: string[]}
    config = function(_, opts)
      require('mason').setup(opts)
      local mr = require 'mason-registry'
      mr:on('package:install:success', function()
        vim.defer_fn(function()
          -- trigger FileType event to possibly load this newly installed LSP server
          require('lazy.core.handler.event').trigger {
            event = 'FileType',
            buf = vim.api.nvim_get_current_buf(),
          }
        end, 100)
      end)

      mr.refresh(function()
        for _, tool in ipairs(opts.ensure_installed) do
          local p = mr.get_package(tool)
          if not p:is_installed() then
            p:install()
          end
        end
      end)
    end,
  },
}
