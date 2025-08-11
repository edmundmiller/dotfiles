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
    nixpkgs.url = "nixpkgs/nixos-unstable"; # Using unstable for 25.05 compatibility
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable"; # for packages on the edge
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nur.url = "github:nix-community/NUR";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # Utils
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    # NOTE https://github.com/danth/stylix/issues/359
    stylix.url = "github:danth/stylix/master";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    stylix.inputs.home-manager.follows = "home-manager";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    # Extras
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    ghostty.url = "git+ssh://git@github.com/ghostty-org/ghostty";
    wezterm.url = "github:wez/wezterm?dir=nix";
    wezterm.inputs.nixpkgs.follows = "nixpkgs";
    "op-shell-plugins".url = "github:1Password/shell-plugins";
    llm-prompt.url = "github:aldoborrero/llm-prompt";
    llm-prompt.inputs.nixpkgs.follows = "nixpkgs";
    zen-browser.url = "github:MarceColl/zen-browser-flake";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      flake-parts,
      nix-darwin,
      ...
    }:
    let
      inherit (lib.my) mapModules mapModulesRec mapHosts;

      # System architectures
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin"; # or x86_64-darwin for Intel Macs

      mkPkgs =
        pkgs: extraOverlays: system:
        import pkgs {
          inherit system;
          config.allowUnfree = true; # forgive me Stallman senpai
          overlays = extraOverlays ++ (lib.attrValues self.overlays);
        };
      
      # Linux packages
      pkgs = mkPkgs nixpkgs [ self.overlay ] linuxSystem;
      pkgs' = mkPkgs nixpkgs-unstable [ ] linuxSystem;
      
      # Darwin packages  
      darwinPkgs = mkPkgs nixpkgs [ self.overlay ] darwinSystem;

      lib = nixpkgs.lib.extend (
        self: _super: {
          my = import ./lib {
            pkgs = pkgs;  # Linux packages for the lib functions
            inherit inputs;
            lib = self;
          };
        }
      );
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.treefmt-nix.flakeModule ];

      flake = {
        lib = lib.my;

        overlay = final: _prev: {
          unstable = if final.stdenv.isDarwin 
                     then mkPkgs nixpkgs-unstable [ ] final.system
                     else pkgs';
          my = self.packages.${final.system} or {};
        };

        overlays = mapModules ./overlays import;

        packages."${linuxSystem}" = mapModules ./packages (p: pkgs.callPackage p { });

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

        apps."${linuxSystem}".default = {
          type = "app";
          program = ./bin/hey;
        };
        
        apps."${darwinSystem}".default = {
          type = "app";
          program = ./bin/hey;
        };

        # Add Darwin configuration
        darwinConfigurations."MacTraitor-Pro" = nix-darwin.lib.darwinSystem {

          system = darwinSystem;
          specialArgs = {
            inherit inputs lib;
          };
          modules = [
            # Add home-manager module first
            inputs.home-manager.darwinModules.home-manager
            
            # Import host-specific configuration
            ./hosts/mactraitorpro/default.nix

            # Basic Darwin settings
            {
              # Define base options
              options.modules = lib.mkOption {
                type = lib.types.attrs;
                default = { };
                description = "Modules configuration options";
              };
              
              config = {
                # Set the dotfiles directory
                environment.variables.DOTFILES = toString ./.;
                environment.variables.DOTFILES_BIN = "$DOTFILES/bin";
                
                services.nix-daemon.enable = true;
                # Use the correct nixpkgs
                nixpkgs.pkgs = darwinPkgs;
                
                nix = {
                  package = darwinPkgs.nixVersions.stable;
                  settings = {
                    experimental-features = [ "nix-command" "flakes" ];
                    substituters = [
                      "https://nix-community.cachix.org"
                      "https://hyprland.cachix.org"
                      "https://cosmic.cachix.org/"
                    ];
                    trusted-public-keys = [
                      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
                      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
                    ];
                  };
                  optimise = {
                    automatic = true;
                    user = "root";
                  };
                };
                
                system.stateVersion = 4;

                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                
                # User configuration
                users.users.emiller = {
                  home = "/Users/emiller";
                  shell = darwinPkgs.zsh;
                };
                
                # Basic packages
                environment.systemPackages = with darwinPkgs; [
                  git
                  vim
                  wget
                  just
                ];
                
              };
            }
          ];
        };
        darwinConfigurations."Seqeratop" = nix-darwin.lib.darwinSystem {
          system = darwinSystem;
          specialArgs = {
            inherit inputs lib;
          };
          modules = [
            # Add home-manager module first
            inputs.home-manager.darwinModules.home-manager
            
            # Import host-specific configuration
            ./hosts/seqeratop/default.nix

            # Basic Darwin settings
            {
              # Define base options
              options.modules = lib.mkOption {
                type = lib.types.attrs;
                default = { };
                description = "Modules configuration options";
              };
              
              config = {
                # Set the dotfiles directory
                environment.variables.DOTFILES = toString ./.;
                environment.variables.DOTFILES_BIN = "$DOTFILES/bin";
                
                services.nix-daemon.enable = true;
                # Use the correct nixpkgs
                nixpkgs.pkgs = darwinPkgs;
                
                nix = {
                  package = darwinPkgs.nixVersions.stable;
                  settings = {
                    experimental-features = [ "nix-command" "flakes" ];
                    substituters = [
                      "https://nix-community.cachix.org"
                      "https://hyprland.cachix.org"
                      "https://cosmic.cachix.org/"
                    ];
                    trusted-public-keys = [
                      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
                      "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
                    ];
                  };
                  optimise = {
                    automatic = true;
                    user = "root";
                  };
                };
                
                system.stateVersion = 4;

                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                
                # User configuration
                users.users.emiller = {
                  home = "/Users/emiller";
                  shell = darwinPkgs.zsh;
                };
                
                # Basic packages
                environment.systemPackages = with darwinPkgs; [
                  git
                  vim
                  wget
                  just
                ];
                
              };
            }
          ];
        };
      };
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
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
