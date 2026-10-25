# TypeScript / JavaScript language server selection

This config runs **two** possible TypeScript language servers and attaches exactly one per project:

- **`tsc`** — TypeScript 7's native Go compiler (`tsgo`) running as `tsc --lsp --stdio`.
  This is also the compiler on the Nix `PATH`, so the editor and the build agree.
- **`vtsls`** — the JavaScript/TypeScript language server that wraps a JS `tsserver`.
  Kept as the fallback for projects pinned to TypeScript 5.x, where `tsgo` would reject
  parts of the config and lose most code actions.

The selection lives in `lua/custom/plugins/languages/typescript.lua`
(`project_ts_major`, `ts7_binary`, `tsgo_should_own`, `setup.tsc`, `setup.vtsls`) and is
regression-tested by `pnpm test`.

## Selection rule

`tsgo` (`tsc`) attaches when **both** hold:

1. The project's TypeScript is **not pinned below 6** — the nearest installed
   `node_modules/typescript/package.json` version, else the declared range in `package.json`
   (`devDependencies`/`dependencies`/`peerDependencies`/`optionalDependencies`).
   Undeclared TypeScript counts as "unknown" and therefore as tsgo territory.
2. A `--lsp`-capable TypeScript 7 binary exists: `node_modules/.bin/tsc`, `node_modules/.bin/tsgo`,
   `tsc` or `tsgo` (first one reporting `major >= 7`).

Otherwise **`vtsls`** attaches.

| Project | Selected server |
| --- | --- |
| `typescript@7.x` installed | `tsc` (tsgo) |
| no `typescript` dependency | `tsc` (tsgo) |
| `typescript: "^5.9.3"` or `5.9.3` installed | `vtsls` |
| TS ≥ 6 but no TS 7 binary anywhere | `vtsls` |
| `deno.json` / `deno.jsonc` ancestor | neither (`denols`, when enabled) |

The two gates fail closed: when a server's `root_dir` decides the other server owns the project it
returns without calling `on_dir`, so a buffer never gets both clients.

### Escape hatches

Both are plain globals evaluated on every `root_dir` call, so they apply to the next attach
(`:e` the buffer, or `:LspRestart`):

```vim
:lua vim.g.ts_lsp_force_vtsls = true   " keep vtsls even for TS 7 projects
:lua vim.g.ts_lsp_force_tsgo = true    " force tsgo even for TS 5 projects
:lua vim.g.ts_lsp_force_tsgo = nil     " back to automatic
```

## Binaries per platform

### Nix (this flake)

| Binary | Version | Source |
| --- | --- | --- |
| `tsc` | 7.0.2 (native Go build, `--lsp`) | `pkgs.typescript` (currently mapped to `typescript_7` in nixpkgs) |
| `tsc5` | 5.9.3 | `overlays/typescript5.nix` → `pkgs.typescript5` |
| `tsserver` | 5.9.3 | same overlay |
| `vtsls` | shipped with nixpkgs | `lspsAndRuntimeDeps` |
| `inotifywait` | inotify-tools | `lspsAndRuntimeDeps` (fast recursive file watching) |

`pkgs.typescript` and `pkgs.typescript_5` both install `bin/tsc`, so they cannot both be added
directly. The overlay exposes the TS 5 CLI as `tsc5`/`tsserver` and leaves `bin/tsc` to TS 7.

Re-check this when bumping `flake.lock`: if nixpkgs maps `typescript` back to TS 5, the Nix `tsc`
stops serving `--lsp`, `ts7_binary` finds nothing and every project falls back to `vtsls`
(degraded, not broken).

### macOS (no Nix, mason)

| Server/CLI | Version | Notes |
| --- | --- | --- |
| `tsc` (mason `tsc` package) | npm `typescript@7.0.2` | **Requires `node` on `PATH`** — the mason package ships a `#!/usr/bin/env node` shim but does not declare Node |
| `vtsls` (mason) | mason default | fallback, installed |
| TS 5 CLI | the project's own | `npx tsc` / `node_modules/.bin/tsc`; there is no mac-side `tsc5` shim |

The deprecated mason `tsgo` package was registry-renamed to `tsc` (2026-08-13);
`lsp/tsgo.lua` in nvim-lspconfig is only a deprecation shim, which is why this config enables
`tsc` and not `tsgo`.

## What `tsgo` does *not* do (yet)

Versus `tsserver`/`vtsls`:

- **No quick fixes.** "Did you mean", "add import", "remove unused import" all return `[]`.
  Auto-imports still work through `completionItem/resolve`.
- **No refactor actions.** `source.organizeImports`, `source.removeUnusedImports` and
  `source.sortImports` do work; the move-to-file refactoring does not.
- **No `executeCommandProvider`** — no `typescript.restartTsServer`, no move-to-file command.
- **Diagnostics are partly pull-based**: source files use `textDocument/diagnostic` (no need to
  save), while project/tsconfig configuration errors still arrive as pushed
  `publishDiagnostics` — they show up on an open `tsconfig.json` even though no client is
  attached to that buffer.
- Read-only file operations: `workspace/willRenameFiles` only.
- Empty semantic-token legend.

Because of that, the vtsls-only `_typescript.moveToFileRefactoring` handler in
`typescript.lua` stays registered but is filtered by client name (`Snacks.util.lsp.on({ name = 'vtsls' }, …)`),
so it simply never runs under `tsc`.
`ts-error-translator.nvim` hooks `publishDiagnostics` and hardcodes the `tsserver`/`vtsls` server
names, so it is inert under `tsc` and stays disabled.
`better-type-hover` and `twoslash-queries` use standard LSP requests and work unchanged.

### tsconfig diagnostics under `tsgo`

A tsconfig written for TypeScript 5 will produce **configuration errors on `tsconfig.json`**
while source files keep type-checking normally. They are shown on purpose — they are the
migration signal. Opening `tsconfig.json` is enough: the project pushes them, so they appear even
though no LSP client is attached to that JSON buffer. Typical ones:

| Code | Cause |
| --- | --- |
| `TS5108` | `target: ES5`, `module: AMD`/`UMD`, `moduleResolution: node`/`node10`/`classic` |
| `TS5102` | `baseUrl`, `outFile` |
| `TS5023` | `importsNotUsedAsValues`, `preserveValueImports`, `charset`, `out`, `suppressImplicitAnyIndexErrors`, `keyofStringsOnly`, `noImplicitUseStrict`, `noStrictGenericChecks`, `suppressExcessPropertyErrors` |

`ignoreDeprecations` accepts anything and does nothing — there is no opt-out.
TS 7 also flips defaults: `target: es2025`, `moduleResolution: bundler`, `strict: true`,
`esModuleInterop`/`allowSyntheticDefaultImports: true`.

This is exactly why TS 5.x projects keep `vtsls` unless you force `tsgo` (`vim.g.ts_lsp_force_tsgo`),
in which case the tsconfig diagnostics are expected.

## Which root resolver is used

- **`tsc` (tsgo)** delegates to nvim-lspconfig's shipped resolver: nearest package-manager
  lock file, `.git`, cwd fallback, plus its own Deno exclusion and TS 7 binary probe/cache.
  This config only puts a version gate in front of it.
- **`vtsls`** uses the custom monorepo/workspace resolver described in
  [vtsls-root-resolution.md](./vtsls-root-resolution.md).
  That resolver, and therefore the TS 5.x server, roots at the workspace top.

## File watching

`lua/custom/plugins/lsp.lua` advertises
`capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = true` for all servers.
Neovim defaults this to `false` on Linux, and without it `tsgo`'s watcher registration is ignored —
`:LspLog` then reports `file watching: disabled` and editing `tsconfig.json` requires `:LspRestart`.
`inotify-tools` is on the Nix `PATH` so Neovim uses inotify rather than polling.

`tsgo` registers watchers for `<root>/**/*` plus its bundled `lib/typescript/**/*`, so very large
repos cost inotify watches.

## How to Verify

Automated (all from the repo root):

```bash
nix build .#dnvim     # TS 7 tsc + tsc5/tsserver + vtsls + inotify-tools coexist
pnpm test             # 12 resolver checks (forced vtsls) + 9 selection checks
pnpm lint             # stylua --check on Lua changed vs main
pnpm typecheck        # loadfile every Lua file
```

`pnpm test` prints one `PASS:` line per check and ends with
`OK: vtsls/tsc LSP selection checks passed`. The selection checks build fake `tsc` binaries
(`Version 7.0.2` / `Version 5.9.3`) and prepend them to a controlled `PATH`, so they do not
depend on what the host has installed.

Runtime, from `./result/bin/nvim`:

```bash
# 1. TS 7 project (or no typescript dependency) -> tsgo
mkdir -p /tmp/ts7/src && cd /tmp/ts7
printf '{"name":"ts7"}\n' > package.json
printf '{"compilerOptions":{"strict":true}}\n' > tsconfig.json
printf 'export const x: number = 1\n' > src/index.ts
printf '{}\n' > package-lock.json

/path/to/result/bin/nvim src/index.ts
```

```vim
:lua =vim.lsp.get_clients({ name = 'tsc' })[1].server_info
" expect { name = 'typescript-go', version = '7.0.2' }; root_dir is the project root
:lua =vim.lsp.codelens.get(0)          " {} - code lenses are disabled
:lua =vim.lsp.inlay_hint.is_enabled()
```

Inlay hints: parameter names/types and return types show, `variableTypes` does not
(`:lua =vim.lsp.config.tsc.settings['js/ts'].inlayHints.variableTypes.enabled` is `false`).

```bash
# 2. TS 5 project -> vtsls
mkdir -p /tmp/ts5/node_modules/typescript /tmp/ts5/src && cd /tmp/ts5
printf '{"name":"ts5","devDependencies":{"typescript":"^5.9.3"}}\n' > package.json
printf '{"version":"5.9.3"}\n' > node_modules/typescript/package.json
printf '{"compilerOptions":{"target":"ES5","moduleResolution":"node","baseUrl":"."}}\n' > tsconfig.json
printf '{}\n' > package-lock.json
printf 'export const y = 1\n' > src/index.ts
```

Expected: an `vtsls` client, no `tsc` client, no `TS5108`/`TS5023` diagnostics on `tsconfig.json`.

```vim
" exactly one of the two servers is running
:lua =vim.tbl_map(function(c) return c.name end,
      \ vim.tbl_filter(function(c) return c.name == 'tsc' or c.name == 'vtsls' end,
      \ vim.lsp.get_clients()))
:lua =vim.lsp.get_clients({ name = 'vtsls' })[1].root_dir   " monorepo/workspace root
```

3. In any project, `:terminal tsc --version` prints `Version 7.0.2` and `tsc5 --version` prints
   `Version 5.9.3` (on the Nix build). `tsserver` is on `PATH` too (it has no `--version`
   flag; it speaks the tsserver protocol) for tooling that still spawns a TS 5 `tsserver`.

4. Forced cross-over:

   ```vim
   :lua vim.g.ts_lsp_force_tsgo = true
   :e
   ```

   The TS 5 fixture now gets a `tsc` client and the legacy tsconfig errors **are** shown on
   `tsconfig.json` (expected). With this fixture's tsconfig (`target: ES5`,
   `moduleResolution: node`, `baseUrl`), the messages read
   `Option 'target=ES5' has been removed…`, `Option 'moduleResolution=node10' has been removed…`
   and `Option 'baseUrl' has been removed…`, while `src/index.ts` keeps type-checking.
   `:lua vim.g.ts_lsp_force_tsgo = nil` plus `:e` restores `vtsls` (and the clean tsconfig).

5. Deno: with a `deno.json` ancestor neither `tsc` nor `vtsls` attaches
   (`denols` is not installed/enabled here).

6. File watching: edit `include` in `tsconfig.json` and confirm `tsgo` picks it up without
   `:LspRestart`; `:LspLog` (with debug logging) shows `Added new watch: root files …` and
   `Updated watches in …ms` instead of `file watching: disabled`.

macOS (manual, cannot be exercised from the Nix build): in `:Mason` the `tsc` package installs
npm `typescript@7.0.2`, `node` is on `PATH`, a TS 7 repo attaches `tsc`, a TS 5 repo attaches
`vtsls`, and `npx tsc --version` in that repo reports the project's own version.
