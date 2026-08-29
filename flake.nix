{
  description = "Portable dotfiles with a native Nix package and Home Manager adapter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    herdr = {
      url = "github:herdrdev/herdr/v0.8.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ai-commit-message-src = {
      url = "github:youguanxinqing/ai-commit-message/v0.1.0";
      flake = false;
    };

    bootmux-src = {
      url = "github:griffinqiu/bootmux/v0.3.3";
      flake = false;
    };

    keep-src = {
      url = "github:youguanxinqing/keep/v0.2.1";
      flake = false;
    };

    staticcheck-src = {
      url = "github:dominikh/go-tools/2026.2.1";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, herdr, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packagesFor = system:
        import ./nix/packages.nix {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          herdrPackage = herdr.packages.${system}.default;
          inherit inputs;
        };
    in
    {
      packages = forAllSystems packagesFor;

      homeModules.nixos = import ./nix/home.nix {
        inherit self;
      };
    };
}
