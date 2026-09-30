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

    # Only what the build needs, so README or test edits don't rebuild the grammar.
    grammarSrc = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [./src ./queries ./tree-sitter.json];
    };
    version = (lib.importJSON ./tree-sitter.json).metadata.version;
  in {
    # Helix `[[language]]` entry. Plain data, so consumers can put it straight
    # into their own languages.toml.
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
      # $out/parser (the shared library) and $out/queries/.
      default = pkgs.tree-sitter.buildGrammar {
        language = "mapfile";
        inherit version;
        src = grammarSrc;
      };

      # Laid out like a Helix runtime dir: grammars/mapfile.so and queries/mapfile/.
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
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);

    devShells = forAllSystems (pkgs: let
      languagesToml = (pkgs.formats.toml {}).generate "languages.toml" {
        language = [self.lib.helixLanguage];
      };

      # Helix with the working tree's grammar and queries. `hx --grammar build`
      # can't write to the store runtime, so hx-dev uses its own config dir in
      # ~/.cache. Helix searches <config dir>/runtime before $HELIX_RUNTIME.
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

          so="$cfg/runtime/grammars/mapfile.so"
          if [ ! -e "$so" ] || [ "$root/src/parser.c" -nt "$so" ]; then
            tree-sitter build -o "$so" "$root"
          fi

          XDG_CONFIG_HOME="$xdg" exec hx "$@"
        '';
      };
    in {
      # mkShell's stdenv provides the C compiler that `tree-sitter test`/`parse` need.
      default = pkgs.mkShell {
        packages = with pkgs; [
          tree-sitter
          nodejs # `tree-sitter generate` evaluates grammar.js with node
          hx-dev
        ];
      };
    });
  };
}
