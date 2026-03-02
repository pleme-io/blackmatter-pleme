{
  description = "Blackmatter Pleme - pleme-io org conventions and Claude Code skills";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }: {
    homeManagerModules.default = import ./module;
  };
}
