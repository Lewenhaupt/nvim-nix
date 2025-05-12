# Copyright (c) 2023 BirdeeHub
# Licensed under the MIT license

# This is an empty nixCats config.
# you may import this template directly into your nvim folder
# and then add plugins to categories here,
# and call the plugins with their default functions
# within your lua, rather than through the nvim package manager's method.
# Use the help, and the example repository https://github.com/BirdeeHub/nixCats-nvim

# It allows for easy adoption of nix,
# while still providing all the extra nix features immediately.
# Configure in lua, check for a few categories, set a few settings,
# output packages with combinations of those categories and settings.

# All the same options you make here will be automatically exported in a form available
# in home manager and in nixosModules, as well as from other flakes.
# each section is tagged with its relevant help section.

{
  description = "A Lua-natic's neovim flake, with extra cats! nixCats!";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "github:khaneliman/nixpkgs/sqlite";
    nixCats.url = "github:BirdeeHub/nixCats-nvim";

    "plugins-ts-error-translator-nvim" = {
      url = "github:dmmulroy/ts-error-translator.nvim";
      flake = false;
    };

    "plugins-twoslash-queries-nvim" = {
      url = "github:marilari88/twoslash-queries.nvim";
      flake = false;
    };
    "plugins-here-term" = {
      url = "github:jaimecgomezz/here.term";
      flake = false;
    };

    "plugins-iswap-nvim" = {
      url = "github:mizlan/iswap.nvim";
      flake = false;
    };

    "plugins-moody-nvim" = {
      url = "github:svampkorg/moody.nvim";
      flake = false;
    };

    "plugins-yankbank-nvim" = {
      url = "github:ptdewey/yankbank-nvim";
      flake = false;
    };

    "plugins-helpview-nvim" = {
      url = "github:OXY2DEV/helpview.nvim";
      flake = false;
    };

    "plugins-snipe-lsp-nvim" = {
      url = "github:kungfusheep/snipe-lsp.nvim";
      flake = false;
    };

    "plugins-snipe-nvim" = {
      url = "github:leath-dub/snipe.nvim";
      flake = false;
    };

    "plugins-diffview-nvim" = {
      url = "github:sindrets/diffview.nvim";
      flake = false;
    };

    "plugins-hypersonic-nvim" = {
      url = "github:tomiis4/hypersonic.nvim";
      flake = false;
    };

    "plugins-messenger-nvim" = {
      url = "github:lsig/messenger.nvim";
      flake = false;
    };
    "plugins-buffer-reopen-nvim" = {
      url = "github:iamyoki/buffer-reopen.nvim";
      flake = false;
    };
    "plugins-kitty-scrollback-nvim" = {
      url = "github:mikesmithgh/kitty-scrollback.nvim";
      flake = false;
    };

    "plugins-direnv-nvim" = {
      url = "github:NotAShelf/direnv.nvim";
      flake = false;
    };

    # neovim-nightly-overlay = {
    #   url = "github:nix-community/neovim-nightly-overlay"; };

    # see :help nixCats.flake.inputs
    # If you want your plugin to be loaded by the standard overlay,
    # i.e. if it wasnt on nixpkgs, but doesnt have an extra build step.
    # Then you should name it "plugins-something"
    # If you wish to define a custom build step not handled by nixpkgs,
    # then you should name it in a different format, and deal with that in the
    # overlay defined for custom builds in the overlays directory.
    # for specific tags, branches and commits, see:
    # https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html#examples

  };

  # see :help nixCats.flake.outputs
  outputs =
    {
      self,
      nixpkgs,
      nixCats,
      ...
    }@inputs:
    let
      inherit (nixCats) utils;
      luaPath = "${./.}";
      forEachSystem = utils.eachSystem nixpkgs.lib.platforms.all;
      # the following extra_pkg_config contains any values
      # which you want to pass to the config set of nixpkgs
      # import nixpkgs { config = extra_pkg_config; inherit system; }
      # will not apply to module imports
      # as that will have your system values
      extra_pkg_config = {
        allowUnfree = true;
      };
      # sometimes our overlays require a ${system} to access the overlay.
      # management of this variable is one of the harder parts of using flakes.

      # so I have done it here in an interesting way to keep it out of the way.

      # First, we will define just our overlays per system.
      # later we will pass them into the builder, and the resulting pkgs set
      # will get passed to the categoryDefinitions and packageDefinitions
      # which follow this section.

      # this allows you to use ${pkgs.system} whenever you want in those sections
      # without fear.
      inherit
        (forEachSystem (
          system:
          let
            # see :help nixCats.flake.outputs.overlays
            dependencyOverlays = # (import ./overlays inputs) ++
              [
                # This overlay grabs all the inputs named in the format
                # `plugins-<pluginName>`
                # Once we add this overlay to our nixpkgs, we are able to
                # use `pkgs.neovimPlugins`, which is a set of our plugins.
                (utils.standardPluginOverlay inputs)
                # add any flake overlays here.
              ];
          in
          # these overlays will be wrapped with ${system}
          # and we will call the same utils.eachSystem function
          # later on to access them.
          {
            inherit dependencyOverlays;
          }
        ))
        dependencyOverlays
        ;
      # see :help nixCats.flake.outputs.categories
      # and
      # :help nixCats.flake.outputs.categoryDefinitions.scheme
      categoryDefinitions =
        {
          pkgs,
          settings,
          categories,
          name,
          ...
        }@packageDef:
        {
          # to define and use a new category, simply add a new list to a set here,
          # and later, you will include categoryname = true; in the set you
          # provide when you build the package using this builder function.
          # see :help nixCats.flake.outputs.packageDefinitions for info on that section.

          # propagatedBuildInputs:
          # this section is for dependencies that should be available
          # at BUILD TIME for plugins. WILL NOT be available to PATH
          # However, they WILL be available to the shell
          # and neovim path when using nix develop
          propagatedBuildInputs = {
            general = with pkgs; [ ];
          };

          # lspsAndRuntimeDeps:
          # this section is for dependencies that should be available
          # at RUN TIME for plugins. Will be available to PATH within neovim terminal
          # this includes LSPs
          lspsAndRuntimeDeps = with pkgs; {
            general = [
              universal-ctags
              ripgrep
              fd
              stdenv.cc.cc
              nix-doc
              lua-language-server
              nixd
              stylua
              nodejs-18_x
              typescript
              nixfmt-rfc-style
            ];
            python = [
              ruff
              python3
              pyright
            ];
            latex = [
              zathura
              texliveFull
            ];
            kickstart-debug = [ delve ];
            kickstart-lint = [
              markdownlint-cli
              biome
              eslint
              eslint_d
              prettierd
              nodePackages.jsonlint
            ];
          };

          # This is for plugins that will load at startup without using packadd:
          startupPlugins = with pkgs.vimPlugins; {
            general = [
              vim-sleuth
              lazy-nvim
              comment-nvim
              gitsigns-nvim
              which-key-nvim
              telescope-nvim
              telescope-ui-select-nvim
              nvim-web-devicons
              plenary-nvim
              nvim-lspconfig
              lazydev-nvim
              fidget-nvim
              conform-nvim
              nvim-cmp
              luasnip
              cmp_luasnip
              cmp-nvim-lsp
              cmp-path
              tokyonight-nvim
              todo-comments-nvim
              nvim-treesitter.withAllGrammars
              neoscroll-nvim
              flash-nvim
              leap-nvim
              smart-splits-nvim
              surround-nvim
              oil-nvim
              trouble-nvim
              typescript-tools-nvim
              substitute-nvim
              arrow-nvim
              noice-nvim
              nui-nvim
              mini-nvim
              {
                name = "mini.icons";
                plugin = mini-icons;
              }
              {
                name = "catppuccin";
                plugin = catppuccin-nvim;
              }
              {
                name = "kitty-scrollback.nvim";
                plugin = pkgs.neovimPlugins.kitty-scrollback-nvim;
              } # not in nixpkgs, probably requires some additional conf to make it work
              {
                name = "ts-error-translator.nvim";
                plugin = pkgs.neovimPlugins.ts-error-translator-nvim;
              }
              {
                name = "twoslash-queries.nvim";
                plugin = pkgs.neovimPlugins.twoslash-queries-nvim;
              }
              {
                name = "here.term";
                plugin = pkgs.neovimPlugins.here-term;
              }
              {
                name = "iswap.nvim";
                plugin = pkgs.neovimPlugins.iswap-nvim;
              }
              {
                name = "moody.nvim";
                plugin = pkgs.neovimPlugins.moody-nvim;
              }
              {
                name = "helpview.nvim";
                plugin = pkgs.neovimPlugins.helpview-nvim;
              }
              {
                name = "diffview.nvim";
                plugin = pkgs.neovimPlugins.diffview-nvim;
              }
              {
                name = "messenger.nvim";
                plugin = pkgs.neovimPlugins.messenger-nvim;
              }
              {
                name = "Hypersonic.nvim";
                plugin = pkgs.neovimPlugins.hypersonic-nvim;
              }
              {
                name = "buffer-reopen.nvim";
                plugin = pkgs.neovimPlugins.buffer-reopen-nvim;
              }
              {
                name = "snipe.nvim";
                plugin = pkgs.neovimPlugins.snipe-nvim;
              }
              {
                name = "snipe-lsp.nvim";
                plugin = pkgs.neovimPlugins.snipe-lsp-nvim;
              }
              {
                name = "direnv.nvim";
                plugin = pkgs.neovimPlugins.direnv-nvim;
              }
              lazygit-nvim
              smart-open-nvim
              telescope-fzy-native-nvim
              telescope-fzf-native-nvim
              pkgs.neovimPlugins.yankbank-nvim
              satellite-nvim

              # This is for if you only want some of the grammars
              # (nvim-treesitter.withPlugins (
              #   plugins: with plugins; [
              #     nix
              #     lua
              #   ]
              # ))
            ];
            latex = [
              vimtex
            ];
            kickstart-debug = [
              nvim-dap
              nvim-dap-ui
              nvim-dap-go
              nvim-nio
            ];
            kickstart-indent_line = [ indent-blankline-nvim ];
            kickstart-lint = [ nvim-lint ];
            kickstart-autopairs = [ nvim-autopairs ];
            kickstart-neo-tree = [
              neo-tree-nvim
              nui-nvim
              # nixCats will filter out duplicate packages
              # so you can put dependencies with stuff even if they're
              # also somewhere else
              nvim-web-devicons
              plenary-nvim
            ];
          };

          # not loaded automatically at startup.
          # use with packadd and an autocommand in config to achieve lazy loading
          # NOTE: this template is using lazy.nvim so, which list you put them in is irrelevant.
          # startupPlugins or optionalPlugins, it doesnt matter, lazy.nvim does the loading.
          # I just put them all in startupPlugins. I could have put them all in here instead.
          optionalPlugins = { };

          # shared libraries to be added to LD_LIBRARY_PATH
          # variable available to nvim runtime
          sharedLibraries = {
            general = with pkgs; [
              sqlite
              # libgit2
            ];
          };

          # environmentVariables:
          # this section is for environmentVariables that should be available
          # at RUN TIME for plugins. Will be available to path within neovim terminal
          environmentVariables = {
            test = {
              CATTESTVAR = "It worked!";
            };
            general = {
              LIBSQLITE = ''"${pkgs.sqlite.out}/lib/libsqlite3.so"'';
            };
          };

          # If you know what these are, you can provide custom ones by category here.
          # If you dont, check this link out:
          # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/setup-hooks/make-wrapper.sh
          extraWrapperArgs = {
            test = [ ''--set CATTESTVAR2 "It worked again!"'' ];
          };

          # lists of the functions you would have passed to
          # python.withPackages or lua.withPackages

          # get the path to this python environment
          # in your lua config via
          # vim.g.python3_host_prog
          # or run from nvim terminal via :!<packagename>-python3
          extraPython3Packages = {
            test = (_: [ ]);
          };
          # populates $LUA_PATH and $LUA_CPATH
          extraLuaPackages = {
            test = [ (_: [ ]) ];
          };
        };

      # And then build a package with specific categories from above here:
      # All categories you wish to include must be marked true,
      # but false may be omitted.
      # This entire set is also passed to nixCats for querying within the lua.

      # see :help nixCats.flake.outputs.packageDefinitions
      packageDefinitions = {
        # These are the names of your packages
        # you can include as many as you wish.
        dnvim =
          { pkgs, ... }:
          {
            # they contain a settings set defined above
            # see :help nixCats.flake.outputs.settings
            settings = {
              wrapRc = true;
              configDirName = "nixCats-nvim";
              # IMPORTANT:
              # your alias may not conflict with your other packages.
              aliases = [
                "vim"
                "vi"
                "nvim"
              ];
              # neovim-unwrapped = inputs.neovim-nightly-overlay.packages.${pkgs.system}.neovim;
            };
            # and a set of categories that you want
            # (and other information to pass to lua)
            categories = {
              general = true;
              gitPlugins = true;
              customPlugins = true;
              test = true;
              python = true;

              kickstart-autopairs = true;
              kickstart-neo-tree = true;
              kickstart-debug = true;
              kickstart-lint = true;
              kickstart-indent_line = true;

              # this kickstart extra didnt require any extra plugins
              # so it doesnt have a category above.
              # but we can still send the info from nix to lua that we want it!
              kickstart-gitsigns = true;

              # we can pass whatever we want actually.
              have_nerd_font = false;

              example = {
                youCan = "add more than just booleans";
                toThisSet = [
                  "and the contents of this categories set"
                  "will be accessible to your lua with"
                  "nixCats('path.to.value')"
                  "see :help nixCats"
                  "and type :NixCats to see the categories set in nvim"
                ];
              };
            };
          };
        ltnvim =
          { pkgs, ... }:
          {
            # they contain a settings set defined above
            # see :help nixCats.flake.outputs.settings
            settings = {
              wrapRc = true;
              configDirName = "nixCats-nvim";
              # IMPORTANT:
              # your alias may not conflict with your other packages.
              aliases = [
                "vim"
                "vi"
                "nvim"
              ];
              # neovim-unwrapped = inputs.neovim-nightly-overlay.packages.${pkgs.system}.neovim;
            };
            # and a set of categories that you want
            # (and other information to pass to lua)
            categories = {
              general = true;
              latex = true;
              gitPlugins = true;
              customPlugins = true;
              test = true;

              kickstart-autopairs = true;
              kickstart-neo-tree = true;
              kickstart-debug = true;
              kickstart-lint = true;
              kickstart-indent_line = true;

              # this kickstart extra didnt require any extra plugins
              # so it doesnt have a category above.
              # but we can still send the info from nix to lua that we want it!
              kickstart-gitsigns = true;

              # we can pass whatever we want actually.
              have_nerd_font = false;

              example = {
                youCan = "add more than just booleans";
                toThisSet = [
                  "and the contents of this categories set"
                  "will be accessible to your lua with"
                  "nixCats('path.to.value')"
                  "see :help nixCats"
                  "and type :NixCats to see the categories set in nvim"
                ];
              };
            };
          };
        testnvim =
          { pkgs, ... }:
          {
            # they contain a settings set defined above
            # see :help nixCats.flake.outputs.settings
            settings = {
              wrapRc = false;
              configDirName = "nixCats-nvim";
              unwrappedCfgPath = "/home/hugo/git/nvim-nix";
              # IMPORTANT:
              # your alias may not conflict with your other packages.
              aliases = [ "tnvim" ];
              # neovim-unwrapped = inputs.neovim-nightly-overlay.packages.${pkgs.system}.neovim;
            };
            # and a set of categories that you want
            # (and other information to pass to lua)
            categories = {
              general = true;
              gitPlugins = true;
              customPlugins = true;
              test = true;

              kickstart-autopairs = true;
              kickstart-neo-tree = true;
              kickstart-debug = true;
              kickstart-lint = true;
              kickstart-indent_line = true;

              # this kickstart extra didnt require any extra plugins
              # so it doesnt have a category above.
              # but we can still send the info from nix to lua that we want it!
              kickstart-gitsigns = true;

              # we can pass whatever we want actually.
              have_nerd_font = false;

              example = {
                youCan = "add more than just booleans";
                toThisSet = [
                  "and the contents of this categories set"
                  "will be accessible to your lua with"
                  "nixCats('path.to.value')"
                  "see :help nixCats"
                  "and type :NixCats to see the categories set in nvim"
                ];
              };
            };
          };
      };
      # In this section, the main thing you will need to do is change the default package name
      # to the name of the packageDefinitions entry you wish to use as the default.
      defaultPackageName = "dnvim";

    in
    # see :help nixCats.flake.outputs.exports
    forEachSystem (
      system:
      let
        nixCatsBuilder = utils.baseBuilder luaPath {
          inherit
            nixpkgs
            system
            dependencyOverlays
            extra_pkg_config
            ;
        } categoryDefinitions packageDefinitions;
        defaultPackage = nixCatsBuilder defaultPackageName;
        # this is just for using utils such as pkgs.mkShell
        # The one used to build neovim is resolved inside the builder
        # and is passed to our categoryDefinitions and packageDefinitions
        pkgs = import nixpkgs { inherit system; };
      in
      {
        # these outputs will be wrapped with ${system} by utils.eachSystem

        # this will make a package out of each of the packageDefinitions defined above
        # and set the default package to the one passed in here.
        packages = utils.mkAllWithDefault defaultPackage;

        # choose your package for devShell
        # and add whatever else you want in it.
        devShells = {
          default = pkgs.mkShell {
            name = defaultPackageName;
            packages = [ defaultPackage ];
            inputsFrom = [ ];
            shellHook = "";
          };
        };

      }
    )
    // {

      # these outputs will be NOT wrapped with ${system}

      # this will make an overlay out of each of the packageDefinitions defined above
      # and set the default overlay to the one named here.
      overlays = utils.makeOverlays luaPath {
        inherit nixpkgs dependencyOverlays extra_pkg_config;
      } categoryDefinitions packageDefinitions defaultPackageName;

      # we also export a nixos module to allow reconfiguration from configuration.nix
      nixosModules.default = utils.mkNixosModules {
        inherit
          defaultPackageName
          dependencyOverlays
          luaPath
          categoryDefinitions
          packageDefinitions
          extra_pkg_config
          nixpkgs
          ;
      };
      # and the same for home manager
      homeModule.default = utils.mkHomeModules {
        inherit nixpkgs;
        inherit
          defaultPackageName
          dependencyOverlays
          luaPath
          categoryDefinitions
          packageDefinitions
          extra_pkg_config
          ;
      };
      inherit utils;
      inherit (utils) templates;
    };
}
