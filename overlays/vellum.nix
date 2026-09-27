importName: inputs: let
  overlay = final: prev: let
    src = inputs.vellum-nvim;
    renderSrc = src + "/render";

    # vellum renders mermaid diagrams, display math and non-PNG images with a
    # headless browser driven by node. Its render/ directory is an npm project
    # and the plugin expects render/node_modules to exist. The standard plugin
    # overlay does not run build steps, so we build the npm dependencies here
    # and wire them into the plugin below.
    renderDeps = final.buildNpmPackage {
      pname = "vellum-nvim-render-deps";
      version = "unstable";
      src = renderSrc;
      npmDepsHash = "sha256-Zcitez2/UGHu4Reux1XwTBwLMzyMDg17Ywa6QXWGTYQ=";
      dontNpmBuild = true;
      # Do not download puppeteer's own Chrome during the build; at runtime
      # PUPPETEER_EXECUTABLE_PATH points at the nix-provided chromium.
      env.PUPPETEER_SKIP_DOWNLOAD = "true";
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -r node_modules "$out/node_modules"
        runHook postInstall
      '';
    };

    vellum-nvim = final.vimUtils.buildVimPlugin {
      pname = "vellum.nvim";
      version = "unstable";
      src = src;
      doCheck = false;
      postInstall = ''
        ln -s ${renderDeps}/node_modules $out/render/node_modules
      '';
    };
  in {
    neovimPlugins = (prev.neovimPlugins or {}) // {
      inherit vellum-nvim;
    };
  };
in
overlay
