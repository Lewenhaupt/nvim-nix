-- Quality-gate entrypoints for this Neovim Lua configuration.
--
-- The agent harness always runs `pnpm typecheck|lint|test`, but this repo has no
-- JavaScript sources. The matching package.json scripts therefore delegate to
-- this file, executed by the same Neovim the configuration targets:
--
--   nvim --headless -u NONE -l scripts/quality-gates.lua <mode>
--
-- Modes:
--   typecheck  parse every tracked/untracked Lua file (loadfile)
--   lint       run stylua --check on Lua files changed relative to main
--   test       regression check for the vtsls root resolver

local mode = (_G.arg and _G.arg[1]) or ''
local failures = 0

---@param message string
local function fail(message)
  failures = failures + 1
  io.stderr:write(('FAIL: %s\n'):format(message))
end

---@param message string
local function info(message)
  io.stdout:write(('OK: %s\n'):format(message))
end

---@param cmd string[]
---@return string output
---@return integer code
local function run(cmd)
  local output = vim.fn.system(cmd)
  return output, vim.v.shell_error
end

---@param pathspec string
---@return string[] files
local function git_lua_files(pathspec)
  local files = vim.fn.systemlist { 'git', 'ls-files', '--cached', '--others', '--exclude-standard', pathspec }
  if vim.v.shell_error ~= 0 then
    return {}
  end
  return files
end

--- Parse every Lua file in the worktree.
local function gate_typecheck()
  local files = git_lua_files '*.lua'
  if #files == 0 then
    return fail 'no Lua files found'
  end
  for _, file in ipairs(files) do
    local chunk, err = loadfile(file)
    if not chunk then
      fail(('%s: %s'):format(file, err))
    end
  end
  info(('parsed %d Lua file(s)'):format(#files))
end

--- Lua files that differ from main (falls back to HEAD), including untracked ones.
---@return string base
---@return string[] files
local function changed_lua_files()
  local base = 'main'
  vim.fn.system { 'git', 'rev-parse', '--verify', '--quiet', base }
  if vim.v.shell_error ~= 0 then
    base = 'HEAD'
  end

  local seen, files = {}, {}
  local lists = {
    vim.fn.systemlist { 'git', 'diff', '--name-only', '--diff-filter=ACMR', base, '--', '*.lua' },
    vim.fn.systemlist { 'git', 'ls-files', '--others', '--exclude-standard', '*.lua' },
  }
  for _, list in ipairs(lists) do
    for _, file in ipairs(list) do
      if not seen[file] and vim.fn.filereadable(file) == 1 then
        seen[file] = true
        files[#files + 1] = file
      end
    end
  end
  return base, files
end

--- Format-check the Lua files touched by this change.
local function gate_lint()
  local base, files = changed_lua_files()
  if #files == 0 then
    info(('no Lua changes relative to %s'):format(base))
    return
  end

  local stylua = vim.fn.exepath 'stylua'
  if stylua == '' then
    return fail 'stylua not found on PATH'
  end

  local cmd = { stylua, '--check' }
  vim.list_extend(cmd, files)
  local output, code = run(cmd)
  if code ~= 0 then
    io.stderr:write(output)
    return fail(('stylua --check failed for: %s'):format(table.concat(files, ', ')))
  end
  info(('stylua --check passed for %d file(s)'):format(#files))
end

--- Regression check for the vtsls monorepo/workspace root resolver.
local function gate_test()
  local lsp_config = vim.lsp and vim.lsp.config
  local config_callable = lsp_config ~= nil and (type(lsp_config) == 'function' or type(rawget(getmetatable(lsp_config) or {}, '__call')) == 'function')
  if not config_callable then
    return fail 'vim.lsp.config unavailable; run via the flake devShell (needs Neovim >= 0.12)'
  end

  local spec_path = vim.fs.joinpath(vim.fn.getcwd(), 'lua/custom/plugins/languages/typescript.lua')
  local spec = dofile(spec_path)
  local setup = spec[1].opts.setup.vtsls

  -- Stub the shipped defaults so the kept Deno mutual-exclusion wrapper is observable.
  ---@param _ integer
  ---@param on_dir fun(dir: string)
  local function denols_default(_, on_dir)
    on_dir 'DENOLS_DEFAULT'
  end

  ---@param _ integer
  ---@param on_dir fun(dir: string)
  local function vtsls_default(_, on_dir)
    on_dir 'VTSLS_DEFAULT'
  end

  vim.lsp.config('denols', { root_dir = denols_default })
  vim.lsp.config('vtsls', { root_dir = vtsls_default })

  -- setup.vtsls also registers a Snacks LSP hook; stub Snacks so the gate does not
  -- depend on the plugin set (or on any other unrelated production behaviour).
  local original_snacks = rawget(_G, 'Snacks')
  local hooks = {}
  _G.Snacks = {
    util = {
      lsp = {
        on = function(hook_spec)
          hooks[#hooks + 1] = hook_spec
        end,
      },
    },
  }
  setup('vtsls', { settings = { typescript = {}, javascript = {} } })
  _G.Snacks = original_snacks

  if #hooks ~= 1 then
    fail(('setup.vtsls should register exactly one Snacks LSP hook, got %d'):format(#hooks))
  end

  if type(vim.lsp.config.vtsls.root_dir) ~= 'function' then
    return fail 'setup.vtsls did not register a root_dir'
  end

  if vim.lsp.config.vtsls.root_dir == vtsls_default then
    return fail 'setup.vtsls kept the shipped default root_dir instead of replacing it'
  end

  ---@param server string
  ---@param path string
  ---@return string|nil
  local function resolve(server, path)
    local bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(bufnr, path)
    local root
    vim.lsp.config[server].root_dir(bufnr, function(dir)
      root = dir
    end)
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return root
  end

  ---@param label string
  ---@param got any
  ---@param want any
  local function check(label, got, want)
    if got == want then
      io.stdout:write(('PASS: %s\n'):format(label))
    else
      fail(('%s: got %s, want %s'):format(label, tostring(got), tostring(want)))
    end
  end

  local function mkdir(path)
    vim.fn.mkdir(path, 'p')
  end

  ---@param path string
  ---@param content string|nil
  local function write(path, content)
    local file = assert(io.open(path, 'w'))
    file:write(content or '')
    file:close()
  end

  local tmp = vim.fn.tempname()
  local function fixture(name)
    local dir = vim.fs.joinpath(tmp, name)
    mkdir(vim.fs.joinpath(dir, 'packages/a/src'))
    return dir
  end

  -- Monorepo manifest (pnpm/turbo) wins over a nested package tsconfig.
  local mono = fixture 'mono'
  write(vim.fs.joinpath(mono, 'pnpm-workspace.yaml'))
  write(vim.fs.joinpath(mono, 'package.json'), '{"name":"root"}')
  write(vim.fs.joinpath(mono, 'packages/a/tsconfig.json'))
  write(vim.fs.joinpath(mono, 'packages/a/src/index.ts'))
  local mono_root = resolve('vtsls', vim.fs.joinpath(mono, 'packages/a/src/index.ts'))
  check('shipped vtsls default not selected', mono_root ~= 'VTSLS_DEFAULT', true)
  check('pnpm-workspace root', mono_root, mono)

  -- A `workspaces` field in package.json is a workspace marker...
  local npm = fixture 'npm-workspaces'
  write(vim.fs.joinpath(npm, 'package.json'), '{"name":"root","workspaces":["packages/*"]}')
  write(vim.fs.joinpath(npm, 'packages/a/package.json'), '{"name":"a"}')
  write(vim.fs.joinpath(npm, 'packages/a/tsconfig.json'))
  write(vim.fs.joinpath(npm, 'packages/a/src/index.ts'))
  check('package.json workspaces root', resolve('vtsls', vim.fs.joinpath(npm, 'packages/a/src/index.ts')), npm)

  -- ...but a plain nested package.json is not: the root lock file wins.
  local plain = fixture 'plain'
  write(vim.fs.joinpath(plain, 'package-lock.json'))
  write(vim.fs.joinpath(plain, 'package.json'), '{"name":"root"}')
  write(vim.fs.joinpath(plain, 'packages/a/package.json'), '{"name":"a"}')
  write(vim.fs.joinpath(plain, 'packages/a/src/index.ts'))
  check('plain nested package.json', resolve('vtsls', vim.fs.joinpath(plain, 'packages/a/src/index.ts')), plain)

  -- An empty workspaces array still marks a workspace root (confirmed decision).
  local empty_ws = fixture 'empty-workspaces'
  write(vim.fs.joinpath(empty_ws, 'package.json'), '{"name":"root","workspaces":[]}')
  write(vim.fs.joinpath(empty_ws, 'packages/a/tsconfig.json'))
  write(vim.fs.joinpath(empty_ws, 'packages/a/src/index.ts'))
  check('empty workspaces array is a marker', resolve('vtsls', vim.fs.joinpath(empty_ws, 'packages/a/src/index.ts')), empty_ws)

  -- A non-table workspaces value is not a workspace marker: fall through to tsconfig.
  local false_ws = fixture 'false-workspaces'
  write(vim.fs.joinpath(false_ws, 'package.json'), '{"name":"root","workspaces":false}')
  write(vim.fs.joinpath(false_ws, 'packages/a/tsconfig.json'))
  write(vim.fs.joinpath(false_ws, 'packages/a/src/index.ts'))
  check('non-table workspaces ignored', resolve('vtsls', vim.fs.joinpath(false_ws, 'packages/a/src/index.ts')), vim.fs.joinpath(false_ws, 'packages/a'))

  -- Malformed package.json is treated as "no workspaces".
  local malformed = fixture 'malformed'
  write(vim.fs.joinpath(malformed, 'yarn.lock'))
  write(vim.fs.joinpath(malformed, 'packages/a/package.json'), '{"workspaces": [}}')
  write(vim.fs.joinpath(malformed, 'packages/a/tsconfig.json'))
  write(vim.fs.joinpath(malformed, 'packages/a/src/index.ts'))
  check('malformed package.json', resolve('vtsls', vim.fs.joinpath(malformed, 'packages/a/src/index.ts')), malformed)

  -- tsconfig-only project falls back to the nearest tsconfig.json.
  local ts = fixture 'tsconfig-only'
  write(vim.fs.joinpath(ts, 'tsconfig.json'))
  write(vim.fs.joinpath(ts, 'packages/a/src/index.ts'))
  check('tsconfig fallback', resolve('vtsls', vim.fs.joinpath(ts, 'packages/a/src/index.ts')), ts)

  -- .git may be a file (worktrees/submodules).
  local gitfile = fixture 'git-file'
  write(vim.fs.joinpath(gitfile, '.git'), 'gitdir: /elsewhere')
  write(vim.fs.joinpath(gitfile, 'packages/a/src/index.ts'))
  check('.git file', resolve('vtsls', vim.fs.joinpath(gitfile, 'packages/a/src/index.ts')), gitfile)

  -- Deno buffers never attach vtsls, and denols keeps its own default.
  local deno = vim.fs.joinpath(tmp, 'deno')
  mkdir(deno)
  write(vim.fs.joinpath(deno, 'deno.json'), '{}')
  write(vim.fs.joinpath(deno, 'index.ts'))
  check('deno buffer skips vtsls', resolve('vtsls', vim.fs.joinpath(deno, 'index.ts')), nil)
  check('deno buffer keeps denols', resolve('denols', vim.fs.joinpath(deno, 'index.ts')), 'DENOLS_DEFAULT')

  -- No markers anywhere falls back to the process cwd.
  local none = fixture 'no-markers'
  write(vim.fs.joinpath(none, 'packages/a/src/index.ts'))
  check('cwd fallback', resolve('vtsls', vim.fs.joinpath(none, 'packages/a/src/index.ts')), vim.fn.getcwd())

  vim.fn.delete(tmp, 'rf')
  if failures == 0 then
    info 'vtsls root resolver checks passed'
  end
end

local modes = {
  typecheck = gate_typecheck,
  lint = gate_lint,
  test = gate_test,
}

local gate = modes[mode]
if not gate then
  io.stderr:write 'usage: nvim -l scripts/quality-gates.lua <typecheck|lint|test>\n'
  vim.cmd 'cq 2'
end

gate()
vim.cmd(failures == 0 and 'cq 0' or 'cq 1')
