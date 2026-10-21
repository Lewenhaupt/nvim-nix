#!/bin/sh
# Quality-gate launcher: pick a usable Neovim, then run scripts/quality-gates.lua.
#
# The agent harness runs `pnpm typecheck|lint|test` with a PATH that has
# nix/pnpm/git but usually no nvim (and never stylua). Resolution order:
#
#   1. $NVIM_BIN, when set and usable (wins over everything)
#   2. a cached flake build under ${XDG_CACHE_HOME:-$HOME/.cache}/nvim-nix-gate
#   3. `nvim` from PATH
#   4. `nix build .#default` (logged; first run may take a minute)
#
# "Usable" means the binary reports Neovim >= 0.12, which is required for
# vim.lsp.config. Missing or too-old binaries are skipped with a reason on
# stderr. A flake build is memoized in the cache file so repeated gate
# invocations do not rebuild; the entry is ignored (and replaced) as soon as
# the path stops existing or stops being executable, and it is always
# re-validated before use.
#
# All diagnostics go to stderr so the gate's own stdout stays parseable.
set -eu

cd "$(dirname "$0")/.."

minimum_major=0
minimum_minor=12
cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/nvim-nix-gate
cache_file=$cache_dir/nvim-path

say() { printf '%s\n' "$*" >&2; }

version_line() {
  "$1" --version 2>/dev/null | head -n 1 || true
}

version_supported() {
  set -- $(printf '%s\n' "$1" | sed -n 's/^NVIM v\([0-9][0-9]*\)\.\([0-9][0-9]*\).*/\1 \2/p')
  [ "$#" -eq 2 ] || return 1
  [ "$1" -gt "$minimum_major" ] && return 0
  [ "$1" -eq "$minimum_major" ] && [ "$2" -ge "$minimum_minor" ]
}

selected=
selected_version=
selected_origin=

consider() {
  bin=$1
  origin=$2
  if [ ! -x "$bin" ]; then
    say "skip $origin: $bin is not executable"
    return 1
  fi
  version=$(version_line "$bin")
  if ! version_supported "$version"; then
    say "skip $origin: $bin reports '${version:-no version}', need Neovim >= $minimum_major.$minimum_minor"
    return 1
  fi
  selected=$bin
  selected_version=$version
  selected_origin=$origin
}

if [ -n "${NVIM_BIN:-}" ]; then
  consider "$NVIM_BIN" 'NVIM_BIN' || say 'NVIM_BIN is unusable; falling back to auto-detection'
fi

if [ -z "$selected" ] && [ -f "$cache_file" ]; then
  cached=$(cat "$cache_file" 2>/dev/null || true)
  if [ -n "$cached" ]; then
    consider "$cached" 'cached flake build' || say "ignoring stale cache: $cache_file"
  fi
fi

if [ -z "$selected" ]; then
  path_nvim=$(command -v nvim 2>/dev/null || true)
  if [ -n "$path_nvim" ]; then
    consider "$path_nvim" 'PATH' || say 'PATH nvim unusable; falling back to the flake'
  fi
fi

if [ -z "$selected" ]; then
  say 'building Neovim from the flake (first run may take a minute)'
  flake_out=$(nix build --no-link --print-out-paths .#default)
  if consider "$flake_out/bin/nvim" 'flake build'; then
    if mkdir -p "$cache_dir" && printf '%s\n' "$selected" >"$cache_file"; then
      :
    else
      say "cache write failed; continuing ($cache_file)"
    fi
  fi
fi

if [ -z "$selected" ]; then
  say 'no usable Neovim found; set NVIM_BIN or run inside the project devShell'
  exit 1
fi

say "nvim: $selected ($selected_version, from $selected_origin)"
exec "$selected" --headless -u NONE -l scripts/quality-gates.lua "$@"
