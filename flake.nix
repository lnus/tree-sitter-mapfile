{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (nixpkgs) lib;
    forAllSystems = f:
      lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]
      (system: f nixpkgs.legacyPackages.${system});

    # Only the build inputs, so doc edits don't rebuild the grammar.
    grammarSrc = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [./src ./queries ./tree-sitter.json];
    };
    version = (lib.importJSON ./tree-sitter.json).metadata.version;
  in {
    # Helix `[[language]]` entry.
    lib.helixLanguage = {
      name = "mapfile";
      scope = "source.mapfile";
      injection-regex = "mapfile";
      file-types = ["map" "sym"];
      comment-token = "#";
      block-comment-tokens = {
        start = "/*";
        end = "*/";
      };
      indent = {
        tab-width = 4;
        unit = "    ";
      };
      grammar = "mapfile";
    };

    packages = forAllSystems (pkgs: rec {
      # $out/parser and $out/queries/.
      default = pkgs.tree-sitter.buildGrammar {
        language = "mapfile";
        inherit version;
        src = grammarSrc;
      };

      helix-runtime = pkgs.linkFarm "mapfile-helix-runtime" [
        {
          name = "grammars/mapfile.so";
          path = "${default}/parser";
        }
        {
          name = "queries/mapfile";
          path = "${default}/queries";
        }
      ];

      # A runtimepath dir, usable as a Neovim plugin.
      neovim-plugin = pkgs.linkFarm "mapfile-neovim-plugin" [
        {
          name = "parser/mapfile.so";
          path = "${default}/parser";
        }
        {
          name = "queries/mapfile";
          path = "${default}/queries/neovim";
        }
      ];
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);

    devShells = forAllSystems (pkgs: let
      languagesToml = (pkgs.formats.toml {}).generate "languages.toml" {
        language = [self.lib.helixLanguage];
      };

      # The dev commands run the working tree's grammar and queries from a
      # config dir in ~/.cache, since the store runtime is read-only.
      buildParser = so: ''
        if [ ! -e "${so}" ] || [ "$root/src/parser.c" -nt "${so}" ]; then
          tree-sitter build -o "${so}" "$root"
        fi
      '';

      hx-dev = pkgs.writeShellApplication {
        name = "hx-dev";
        runtimeInputs = with pkgs; [git helix stdenv.cc tree-sitter];
        text = ''
          root=$(git rev-parse --show-toplevel)
          xdg="''${XDG_CACHE_HOME:-$HOME/.cache}/tree-sitter-mapfile/xdg"
          cfg="$xdg/helix"

          mkdir -p "$cfg/runtime/grammars" "$cfg/runtime/queries"
          ln -sfn ${languagesToml} "$cfg/languages.toml"
          ln -sfn "$root/queries" "$cfg/runtime/queries/mapfile"
          ${buildParser "$cfg/runtime/grammars/mapfile.so"}

          XDG_CONFIG_HOME="$xdg" exec hx "$@"
        '';
      };

      nvimInit = pkgs.writeText "init.lua" ''
        vim.opt.rtp:append({
          '${pkgs.vimPlugins.nvim-treesitter}',
          '${pkgs.vimPlugins.nvim-treesitter-textobjects}',
        })

        vim.filetype.add({ extension = { sym = 'map' } })
        vim.treesitter.language.register('mapfile', { 'map' })

        vim.api.nvim_create_autocmd('FileType', {
          pattern = 'map',
          callback = function()
            vim.treesitter.start()
            vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
            vim.wo[0][0].foldmethod = 'expr'
            vim.wo[0][0].foldlevel = 99
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end,
        })

        local select = require('nvim-treesitter-textobjects.select')
        for keys, obj in pairs({ ac = '@class.outer', ic = '@class.inner', af = '@call.outer', ['if'] = '@call.inner' }) do
          vim.keymap.set({ 'x', 'o' }, keys, function() select.select_textobject(obj, 'textobjects') end)
        end
      '';

      nvim-dev = pkgs.writeShellApplication {
        name = "nvim-dev";
        runtimeInputs = with pkgs; [git neovim stdenv.cc tree-sitter];
        text = ''
          root=$(git rev-parse --show-toplevel)
          xdg="''${XDG_CACHE_HOME:-$HOME/.cache}/tree-sitter-mapfile/xdg"
          cfg="$xdg/nvim"

          mkdir -p "$cfg/parser" "$cfg/queries"
          ln -sfn ${nvimInit} "$cfg/init.lua"
          ln -sfn "$root/queries/neovim" "$cfg/queries/mapfile"
          ${buildParser "$cfg/parser/mapfile.so"}

          XDG_CONFIG_HOME="$xdg" exec nvim "$@"
        '';
      };
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          tree-sitter
          nodejs # for `tree-sitter generate`
          hx-dev
          nvim-dev
        ];
      };
    });
  };
}
