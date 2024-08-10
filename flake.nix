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
    # Core dependencies.
    # Two inputs so I can track them separately at different rates.
    nixpkgs.url = "nixpkgs/nixos-24.05"; # primary nixpkgs
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable"; # for packages on the edge
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nur.url = "github:nix-community/NUR";

    # Utils
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.url = "github:serokell/deploy-rs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    stylix.url = "github:danth/stylix/release-24.05";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    # Extras
    nixos-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    nixos-cosmic.inputs.nixpkgs.follows = "nixpkgs";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixvim.url = "github:nix-community/nixvim/nixos-24.05";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    ghostty.url = "git+ssh://git@github.com/ghostty-org/ghostty";
    wezterm.url = "github:wez/wezterm?dir=nix";
    wezterm.inputs.nixpkgs.follows = "nixpkgs";
    "op-shell-plugins".url = "github:1Password/shell-plugins";
  };

  outputs =
    inputs@{
      flake-parts,
      self,
      nixpkgs,
      nixpkgs-unstable,
      ...
    }:
    let
      inherit (lib.my) mapModules mapModulesRec mapHosts;

      system = "x86_64-linux";

      mkPkgs =
        pkgs: extraOverlays:
        import pkgs {
          inherit system;
          config.allowUnfree = true; # forgive me Stallman senpai
          overlays = extraOverlays ++ (lib.attrValues self.overlays);
        };
      pkgs = mkPkgs nixpkgs [ self.overlay ];
      pkgs' = mkPkgs nixpkgs-unstable [ ];

      lib = nixpkgs.lib.extend (
        self: _super: {
          my = import ./lib {
            inherit pkgs inputs;
            lib = self;
          };
        }
      );
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.treefmt-nix.flakeModule ];

      flake = {
        lib = lib.my;

        overlay = _final: _prev: {
          unstable = pkgs';
          my = self.packages."${system}";
        };

        overlays = mapModules ./overlays import;

        packages."${system}" = mapModules ./packages (p: pkgs.callPackage p { });

        nixosModules = {
          dotfiles = import ./.;
        } // mapModulesRec ./modules import;

        nixosConfigurations = mapHosts ./hosts { };

        templates = {
          full = {
            path = ./.;
            description = "A grossly incandescent nixos config";
          };
          minimal = {
            path = ./templates/minimal;
            description = "A grossly incandescent and minimal nixos config";
          };
          default = self.templates.minimal;
        };

        apps."${system}".default = {
          type = "app";
          program = ./bin/hey;
        };
      };
      systems = [ "x86_64-linux" ];
      perSystem = _: {
        treefmt = {
          projectRootFile = ".git/config";
          programs.deadnix.enable = true;
          programs.nixfmt.enable = true;
          programs.prettier.enable = true;
          programs.statix.enable = true;
        };
      };
    };
}
