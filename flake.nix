{
  description = "Blackmatter Pleme - pleme-io org conventions and Claude Code skills";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, substrate, devenv }:
  let
    lib = nixpkgs.lib;
    forAllSystems = lib.genAttrs [
      "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"
    ];
  in {
    homeManagerModules.default = import ./module {
      skillHelpers = import "${substrate}/lib/hm-skill-helpers.nix" { inherit lib; };
    };

    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = devenv.lib.mkShell {
        inputs = { inherit nixpkgs devenv; };
        inherit pkgs;
        modules = [{
          languages.nix.enable = true;
          packages = with pkgs; [ nixpkgs-fmt nil ];
          git-hooks.hooks.nixpkgs-fmt.enable = true;
        }];
      };
    });
  };
}
