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
--   test       regression checks for the vtsls root resolver and the
--              vtsls/tsgo (tsc) server selection gate

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

--- Regression checks for the vtsls monorepo root resolver and the
--- vtsls / tsgo (`tsc`) server selection gate.
local function gate_test()
  local lsp_config = vim.lsp and vim.lsp.config
  local config_callable = lsp_config ~= nil and (type(lsp_config) == 'function' or type(rawget(getmetatable(lsp_config) or {}, '__call')) == 'function')
  if not config_callable then
    return fail 'vim.lsp.config unavailable; run via the flake devShell (needs Neovim >= 0.12)'
  end

  local spec_path = vim.fs.joinpath(vim.fn.getcwd(), 'lua/custom/plugins/languages/typescript.lua')
  local spec = dofile(spec_path)
  local setup_vtsls = spec[1].opts.setup.vtsls
  local setup_tsc = spec[1].opts.setup.tsc

  local function mkdir(path)
    vim.fn.mkdir(path, 'p')
  end

  ---@param path string
  ---@param content string|nil
  local function write(path, content)
    mkdir(vim.fs.dirname(path))
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

  -- Deterministic TS 7 / TS 5 probes: the gate must not depend on the ambient
  -- PATH (flake wrapper) or on whatever `tsc` the host happens to expose.
  local fake_ts7 = vim.fs.joinpath(tmp, 'fake-bin')
  local fake_ts5 = vim.fs.joinpath(tmp, 'fake-ts5-bin')
  write(vim.fs.joinpath(fake_ts7, 'tsc'), '#!/bin/sh\necho "Version 7.0.2"\n')
  write(vim.fs.joinpath(fake_ts5, 'tsc'), '#!/bin/sh\necho "Version 5.9.3"\n')
  vim.fn.system { 'chmod', '+x', vim.fs.joinpath(fake_ts7, 'tsc'), vim.fs.joinpath(fake_ts5, 'tsc') }

  local original_path = vim.env.PATH or ''
  ---@param dir string|nil prepended directory; nil keeps the ambient PATH
  ---@param exact boolean|nil replace PATH instead of prepending
  local function set_path(dir, exact)
    if not dir then
      vim.env.PATH = original_path
    elseif exact then
      vim.env.PATH = dir
    else
      vim.env.PATH = dir .. ':' .. original_path
    end
  end
  local path_ts7 = fake_ts7
  local path_ts5 = fake_ts5

  -- Stub the shipped defaults so the overridden root_dir hooks are observable.
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

  ---@param _ integer
  ---@param on_dir fun(dir: string)
  local function tsc_default(_, on_dir)
    on_dir 'TSC_DEFAULT'
  end

  vim.lsp.config('denols', { root_dir = denols_default })
  vim.lsp.config('vtsls', { root_dir = vtsls_default })
  vim.lsp.config('tsc', { root_dir = tsc_default })

  -- The setup hooks also register a Snacks LSP hook; stub Snacks so the gate does
  -- not depend on the plugin set (or on any other unrelated production behaviour).
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
  setup_vtsls('vtsls', { settings = { typescript = {}, javascript = {} } })
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

  setup_tsc('tsc', { settings = { typescript = {}, javascript = {} } })

  if type(vim.lsp.config.tsc.root_dir) ~= 'function' then
    return fail 'setup.tsc did not register a root_dir'
  end

  if vim.lsp.config.tsc.root_dir == tsc_default then
    return fail 'setup.tsc kept the shipped default root_dir instead of wrapping it'
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

  --- Reset the vim.g escape hatches used by the selection gate.
  ---@param vtsls boolean|nil
  ---@param tsgo boolean|nil
  local function force(vtsls, tsgo)
    vim.g.ts_lsp_force_vtsls = vtsls
    vim.g.ts_lsp_force_tsgo = tsgo
  end

  --- Project fixture with the given files, rooted by a lock file.
  ---@param name string
  ---@param files table<string, string>
  ---@return string dir
  local function project(name, files)
    local dir = fixture(name)
    write(vim.fs.joinpath(dir, 'package-lock.json'))
    for path, content in pairs(files) do
      write(vim.fs.joinpath(dir, path), content)
    end
    return dir
  end

  -- The 12 resolver checks below exercise the monorepo resolver itself, so the
  -- version gate is forced off (these fixtures declare no TypeScript at all).
  force(true, nil)
  set_path(path_ts7)

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

  -- TS 5 project (installed compiler): vtsls owns it, tsgo must not attach.
  local ts5_installed = project('ts5-installed', {
    ['node_modules/typescript/package.json'] = '{"version":"5.9.3"}',
    ['packages/a/src/index.ts'] = '',
  })
  local ts5_installed_file = vim.fs.joinpath(ts5_installed, 'packages/a/src/index.ts')

  -- TS 5 project (declared range only): vtsls owns it as well.
  local ts5_declared = project('ts5-declared', {
    ['package.json'] = '{"name":"ts5","devDependencies":{"typescript":"^5.9.3"}}',
    ['packages/a/src/index.ts'] = '',
  })
  local ts5_declared_file = vim.fs.joinpath(ts5_declared, 'packages/a/src/index.ts')

  -- TS 7 project (installed compiler): tsgo owns it.
  local ts7_installed = project('ts7-installed', {
    ['node_modules/typescript/package.json'] = '{"version":"7.0.2"}',
    ['packages/a/src/index.ts'] = '',
  })
  local ts7_installed_file = vim.fs.joinpath(ts7_installed, 'packages/a/src/index.ts')

  -- No TypeScript dependency: unknown ⇒ tsgo (documented default).
  local ts_unknown = project('ts-unknown', {
    ['package.json'] = '{"name":"unknown"}',
    ['packages/a/src/index.ts'] = '',
  })
  local ts_unknown_file = vim.fs.joinpath(ts_unknown, 'packages/a/src/index.ts')

  -- tsc gate: TS 5.9.3 installed ⇒ no attach.
  force(nil, nil)
  set_path(path_ts7)
  check('tsc: TS 5.9.3 installed does not attach', resolve('tsc', ts5_installed_file), nil)

  -- tsc gate: TS 5 declared range ⇒ no attach.
  check('tsc: TS 5 declared range does not attach', resolve('tsc', ts5_declared_file), nil)

  -- tsc gate: TS 7 installed ⇒ attaches (shipped resolver).
  check('tsc: TS 7 installed attaches', resolve('tsc', ts7_installed_file), 'TSC_DEFAULT')

  -- tsc gate: no typescript dependency ⇒ attaches (unknown ⇒ tsgo).
  check('tsc: no typescript dependency attaches', resolve('tsc', ts_unknown_file), 'TSC_DEFAULT')

  -- tsc gate: forced tsgo overrides a TS 5 pin.
  force(nil, true)
  check('tsc: forced tsgo overrides a TS 5 pin', resolve('tsc', ts5_installed_file), 'TSC_DEFAULT')

  -- vtsls gate: a TS 5 project still attaches vtsls even with a TS 7 binary on PATH.
  force(nil, nil)
  set_path(path_ts7)
  check('vtsls: TS 5 project attaches', resolve('vtsls', ts5_installed_file), ts5_installed)

  -- vtsls gate: a TS 7 project refuses (tsgo owns it).
  check('vtsls: TS 7 project refuses', resolve('vtsls', ts7_installed_file), nil)

  -- vtsls gate: no TS 7 binary anywhere ⇒ fall back to vtsls even for TS 7.
  set_path(path_ts5, true)
  check('vtsls: no TS 7 binary falls back', resolve('vtsls', ts7_installed_file), ts7_installed)

  -- vtsls gate: forced vtsls overrides.
  set_path(path_ts7)
  force(true, nil)
  check('vtsls: forced vtsls overrides', resolve('vtsls', ts7_installed_file), ts7_installed)

  -- Restore environment and clean up.
  force(nil, nil)
  set_path(nil)
  vim.fn.delete(tmp, 'rf')
  if failures == 0 then
    info 'vtsls/tsc LSP selection checks passed'
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
