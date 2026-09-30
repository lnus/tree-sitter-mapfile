{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    languagesToml = (pkgs.formats.toml {}).generate "languages.toml" {
      language = [
        {
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
        }
      ];
    };

    # Helix with this grammar and queries. `hx --grammar build` can't write to
    # the store runtime, so hx-dev uses its own config dir in ~/.cache.
    # Helix searches <config dir>/runtime before $HELIX_RUNTIME.
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
    formatter.${system} = pkgs.alejandra;

    # mkShell's stdenv provides the C compiler that `tree-sitter test`/`parse` need.
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        tree-sitter
        nodejs # `tree-sitter generate` evaluates grammar.js with node
        hx-dev
      ];
    };
  };
}
