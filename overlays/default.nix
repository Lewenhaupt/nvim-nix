# Custom overlays for plugins that need a build step nixpkgs'
# standardPluginOverlay cannot handle.
# See :help nixCats.flake.nixperts.overlays
inputs: let
  overlaySet = {
    # these items become available as pkgs.neovimPlugins.<name>
    vellum = import ./vellum.nix;
  };
in
builtins.attrValues (builtins.mapAttrs (name: value: (value name inputs)) overlaySet)
