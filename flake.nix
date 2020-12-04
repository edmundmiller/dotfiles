# flake.nix
#
# Author:  Edmund Miller <edmund.a.miller@gmail.com>
# URL:     https://github.com/emiller88/dotfiles
# License: MIT
#
# Welcome to ground zero. Where the whole flake gets set up and all its modules
# are loaded.

{
  description = "A grossly incandescent nixos config.";

  inputs = {
    # Core dependencies
    nixos.url = "nixpkgs/nixos-20.09";
    nixos-unstable.url = "nixpkgs/nixos-unstable";
    home-manager.url =
      "github:rycee/home-manager?rev=c1faa848c5224452660cd6d2e0f4bd3e8d206419";
    home-manager.inputs.nixpkgs.follows = "nixos-unstable";

    # Extras
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    guix.url = "github:emiller88/guix";
    guix.inputs.nixpkgs.follows = "nixos-unstable";
  };

  outputs = inputs@{ self, nixos, nixos-unstable, home-manager, ... }:
    let
      inherit (builtins) baseNameOf;
      inherit (lib) nixosSystem mkIf removeSuffix attrNames attrValues;
      inherit (lib.my) dotFilesDir mapModules mapModulesRec mapHosts;

      system = "x86_64-linux";

      lib = nixos.lib.extend + (self: super: {
        my = import ./lib {
          inherit pkgs inputs;
          lib = self;
        };
      });

      mkPkgs = pkgs: extraOverlays:
        import pkgs {
          inherit system;
          config.allowUnfree = true; # forgive me Stallman senpai
          overlays = extraOverlays ++ (attrValues self.overlays);
        };
      pkgs = mkPkgs nixos [ self.overlay ];
      unstable = mkPkgs nixos-unstable [ ];
    in {
      lib = lib.my;

      overlay = final: prev: {
        inherit unstable;
        user = self.packages."${system}";
      };

      overlays = mapModules ./overlays import;

      packages."${system}" = mapModules ./packages (p: pkgs.callPackage p { });

      nixosModules = {
        dotfiles = import ./.;
      } // mapModulesRec ./modules import;

      nixosConfigurations = mapHosts ./hosts { inherit system; };
    };
}
