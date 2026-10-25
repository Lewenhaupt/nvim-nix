# Custom overlays for plugins that need a build step nixpkgs'
# standardPluginOverlay cannot handle.
# See :help nixCats.flake.nixperts.overlays
inputs: let
  overlaySet = {
    # these items become available as pkgs.neovimPlugins.<name>
    vellum = import ./vellum.nix;
    # Nix-only TS 5 CLI exposed as tsc5/tsserver (pkgs.typescript5).
    typescript5 = import ./typescript5.nix;
  };
in
builtins.attrValues (builtins.mapAttrs (name: value: (value name inputs)) overlaySet)
