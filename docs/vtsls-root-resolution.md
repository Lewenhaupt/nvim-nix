# vtsls workspace root resolution

`lua/custom/plugins/languages/typescript.lua` overrides the `root_dir` used by `vtsls`
(in the `setup.vtsls` hook) instead of relying on the one shipped by nvim-lspconfig.
The shipped resolver only looks for lock files and `.git`,
so a file in `packages/a/src/index.ts` could end up with an LSP workspace rooted at `packages/a`.
The new resolver prefers the monorepo/workspace root, which is what makes cross-package imports,
project-wide diagnostics and the workspace TypeScript SDK resolve correctly.

This resolver applies **when `vtsls` is the selected server** — i.e. for projects pinned to
TypeScript 5.x, or when no `--lsp`-capable TypeScript 7 binary is available.
Projects on TypeScript ≥ 6 (or with no declared TypeScript) are served by `tsc` (tsgo),
which uses nvim-lspconfig's shipped resolver instead.
See [typescript-lsp.md](./typescript-lsp.md) for the selection rule and the
`vim.g.ts_lsp_force_vtsls` / `vim.g.ts_lsp_force_tsgo` overrides.

Nothing to configure: it applies to every TypeScript/JavaScript buffer that `vtsls` serves.

> The automated gate below forces `vim.g.ts_lsp_force_vtsls = true` for the resolver checks,
> because the resolver fixtures declare no TypeScript at all and would otherwise be tsgo's.

## How to Use

Open any `.ts`, `.tsx`, `.js` or `.jsx` file as usual.
`vtsls` starts with a workspace root taken from the **nearest ancestor directory** that matches the first group
that matches at all:

1. Workspace manifests — any of `pnpm-workspace.yaml`, `turbo.json`, `nx.json`,
   `lerna.json`, `rush.json`, or a `package.json` whose decoded JSON contains a
   table-valued `workspaces` field.
2. Lock files — `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lockb`,
   `bun.lock`.
3. `.git` (matches a directory *or* a file, so git worktrees and submodules work).
4. `tsconfig.json` / `jsconfig.json`.
5. `vim.fn.getcwd()` if nothing above matches.

Group priority beats distance: a lock file in the repo root wins over a `tsconfig.json` in the file's own package.

### Supported layouts

pnpm workspaces — `packages/a/src/index.ts` roots at `repo/`:

```text
repo/
├── pnpm-workspace.yaml        ← workspace root
├── package.json
└── packages/a/
    ├── tsconfig.json
    └── src/index.ts
```

Turborepo — same shape, `turbo.json` at the repo root is the marker:

```text
repo/
├── turbo.json                 ← workspace root
├── package.json
└── apps/web/src/index.ts
```

Nx — `nx.json` at the repo root:

```text
repo/
├── nx.json                    ← workspace root
└── libs/ui/src/index.ts
```

Lerna — `lerna.json` at the repo root:

```text
repo/
├── lerna.json                 ← workspace root
└── packages/a/src/index.ts
```

Rush — `rush.json` at the repo root:

```text
repo/
├── rush.json                  ← workspace root
└── packages/a/src/index.ts
```

npm/yarn workspaces — a `workspaces` array (or object) in the root `package.json`:

```text
repo/
├── package.json               ← {"workspaces": ["packages/*"]}
└── packages/a/
    ├── package.json
    └── src/index.ts
```

Plain git repo — no workspace tooling, `vtsls` still roots at the repo top so imports resolve against the whole tree:

```text
repo/
├── .git/                      ← workspace root (a .git *file* also counts)
└── packages/a/src/index.ts
```

tsconfig-only project — no git, no lock file, nearest `tsconfig.json`:

```text
repo/
├── tsconfig.json              ← workspace root
└── src/index.ts
```

### Deno projects

Unchanged: if any ancestor of the buffer contains `deno.json` or `deno.jsonc`, `vtsls` never attaches —
its `root_dir` returns without calling `on_dir`, so no root is reported and no client starts.
`denols` (when you enable it) keeps its own shipped resolution; that half of the hook is untouched.

```text
repo/
├── deno.json                  ← vtsls stays off; denols owns it if enabled
└── src/index.ts
```

### Why the workspace root matters for the TS SDK

`settings.vtsls.autoUseWorkspaceTsdk = true` is set for `vtsls`, so it looks for a workspace-local TypeScript install
(the `typescript` package reachable from the workspace root, or the `typescript.tsdk` path anchored there)
before falling back to its bundled compiler.
If the root is a nested package without the hoisted `node_modules`,
the workspace SDK is not found and you silently get a different compiler version than the project builds with.
Rooting at the workspace top is what keeps the editor's TypeScript in sync with the repo's.

## How to Verify

All commands run from the repo root unless stated otherwise.
Neovim 0.12.5 comes from the flake; no `vtsls` binary has to be installed for the automated gate.

1. **Resolved root in a running Neovim.**
   The resolver lives in the Lua config, so build the wrapper from this repo first,
   then create a monorepo fixture and open it:

   ```bash
   nix build .#default

   mkdir -p /tmp/mono/packages/a/src
   printf 'packages:\n  - "packages/*"\n' > /tmp/mono/pnpm-workspace.yaml
   printf '{"name":"mono","private":true}\n' > /tmp/mono/package.json
   printf '{}\n' > /tmp/mono/packages/a/tsconfig.json
   printf 'export const x: number = 1\n' > /tmp/mono/packages/a/src/index.ts

   ./result/bin/nvim /tmp/mono/packages/a/src/index.ts
   ```

   In that Neovim session:

   ```vim
   :lua vim.print(vim.lsp.get_clients({ name = 'vtsls' })[1].root_dir)
   ```

   Expected: `/tmp/mono` (the monorepo root), not `/tmp/mono/packages/a`.

2. **Deno stays off vtsls.**
   Same approach with a `deno.json` ancestor:

   ```bash
   mkdir -p /tmp/deno-proj
   printf '{}\n' > /tmp/deno-proj/deno.json
   printf 'export const y = 1\n' > /tmp/deno-proj/index.ts
   ./result/bin/nvim /tmp/deno-proj/index.ts
   ```

   ```vim
   :lua vim.print(#vim.lsp.get_clients({ name = 'vtsls' }))
   ```

   Expected: `0` — no `vtsls` client is started for the Deno buffer.

3. **Automated regression gate** (headless, no plugins needed):

   ```bash
   pnpm test        # 12 resolver checks + 9 tsc/vtsls selection checks
   pnpm lint        # stylua --check on Lua files changed vs main
   pnpm typecheck   # loadfile() every Lua file in the worktree
   ```

   Or invoke the gate script directly:

   ```bash
   nvim --headless -u NONE --noplugin -l scripts/quality-gates.lua test
   ```

   `scripts/run-gate.sh` (what the `pnpm` scripts call) picks the Neovim in this order:
   `$NVIM_BIN` → cached flake build under `${XDG_CACHE_HOME:-$HOME/.cache}/nvim-nix-gate` → `nvim` from `PATH` →
   `nix build .#default`.
   The first flake build can take a minute; later runs reuse the cache.
   Every candidate must report Neovim >= 0.12, otherwise it is skipped with the reason printed to stderr.

4. **Expected gate output.**
   Twelve `PASS:` lines for the resolver, nine more for the server selection, followed by the summary line:

   ```text
   PASS: shipped vtsls default not selected
   PASS: pnpm-workspace root
   PASS: package.json workspaces root
   PASS: plain nested package.json
   PASS: empty workspaces array is a marker
   PASS: non-table workspaces ignored
   PASS: malformed package.json
   PASS: tsconfig fallback
   PASS: .git file
   PASS: deno buffer skips vtsls
   PASS: deno buffer keeps denols
   PASS: cwd fallback
   PASS: tsc: TS 5.9.3 installed does not attach
   PASS: tsc: TS 5 declared range does not attach
   PASS: tsc: TS 7 installed attaches
   PASS: tsc: no typescript dependency attaches
   PASS: tsc: forced tsgo overrides a TS 5 pin
   PASS: vtsls: TS 5 project attaches
   PASS: vtsls: TS 7 project refuses
   PASS: vtsls: no TS 7 binary falls back
   PASS: vtsls: forced vtsls overrides
   OK: vtsls/tsc LSP selection checks passed
   ```

   Exit status is `0`; any failure prints a `FAIL:` line and exits non-zero.

5. **Format check.**

   ```bash
   stylua --check lua/custom/plugins/languages/typescript.lua
   ```

   `stylua` comes with the flake but is not on a plain shell `PATH`, so either use `pnpm lint`
   (same check, run through Neovim) or take the binary from Neovim's own `PATH`:

   ```bash
   "$(nvim --headless -u NONE --noplugin -c 'lua io.write(vim.fn.exepath("stylua"))' -c 'qa!' 2>/dev/null)" \
     --check lua/custom/plugins/languages/typescript.lua
   ```

   Expected: no output, exit `0`.
   Style rules come from `.stylua.toml` (160 columns, 2-space indent, single quotes).

### Repo plumbing behind `pnpm test|lint|typecheck`

This is a Lua-only repo, so the three scripts in `package.json`
(`typecheck`, `lint`, `test`)
delegate to `scripts/run-gate.sh`, which runs `scripts/quality-gates.lua` inside the flake's Neovim.
`pnpm-workspace.yaml` only sets `verifyDepsBeforeRun: false` so pnpm does not create a lock file or `node_modules/`
for a dependency-free repo.
If you change the resolver, keep `scripts/quality-gates.lua`'s expectations in sync so these gates stay honest.

## Troubleshooting / Notes

- **`vtsls` still roots at a nested package.**
  Walk the file's ancestor chain: a nearer group-1 marker wins,
  so `packages/a/pnpm-workspace.yaml` intentionally beats a repo-root `turbo.json`.
  Delete the stray marker if you want the outer root.
  `:lua vim.print(vim.inspect(vim.lsp.config.vtsls.root_dir))` printing a `function`
  (not a table) confirms this config's resolver, rather than another plugin's spec, is the one registered.
- **`"workspaces": false` (or any other non-table value) is ignored**, so resolution falls through to the next group.
  `"workspaces": []` *is* treated as a marker.
- **Unreadable or malformed `package.json`** is treated as "no workspaces": no
  error is raised and resolution continues to the next group/marker.
- **An open session did not pick up a change.**
  `root_dir` is evaluated when the client attaches, so reopen the buffer or restart Neovim.
  Fixtures created under `/tmp` need a fresh buffer too — a buffer opened before the fixture existed keeps its old root.
- **`pnpm test` reports `vim.lsp.config unavailable`.**
  The resolved Neovim is older than 0.12.
  Set `NVIM_BIN=/path/to/nvim` (>= 0.12) or run inside the project devShell (`nix develop`), then re-run.
- **`stylua not found on PATH` from the lint gate** means the gate ran under a Neovim that is not the flake build.
  Point `NVIM_BIN` at the flake Neovim, whose `PATH` includes `stylua`.
