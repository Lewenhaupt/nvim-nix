# TypeScript 5 CLI without colliding with the TypeScript 7 `tsc` on PATH.
#
# pkgs.typescript (7.x, tsgo) and pkgs.typescript_5 (5.9.x) both install
# bin/tsc, so they cannot both be added to lspsAndRuntimeDeps as they are.
# TS 7 keeps the `tsc` name (nvim-lspconfig's `tsc` server probes it for
# --lsp), and the TS 5 CLI is exposed as `tsc5`/`tsserver` from here.
#
# Nix-only: on macOS the TS 5 CLI comes from the project (`npx tsc`).
importName: inputs: final: prev: let
  ts5 = final.typescript_5; # npm build: bin/tsc + bin/tsserver
in {
  typescript5 = final.runCommand "typescript-5-cli" {} ''
    mkdir -p $out/bin
    ln -s ${ts5}/bin/tsc $out/bin/tsc5
    ln -s ${ts5}/bin/tsserver $out/bin/tsserver
  '';
}
