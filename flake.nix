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
    treefmt-nix.url = "github:numtide/treefmt-nix";

    # Extras
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    ghostty.url = "github:ghostty-org/ghostty";
    wezterm.url = "github:wez/wezterm?dir=nix";
    wezterm.inputs.nixpkgs.follows = "nixpkgs";
    "op-shell-plugins".url = "github:1Password/shell-plugins";
    opnix.url = "github:brizzbuzz/opnix";
    llm-prompt.url = "github:aldoborrero/llm-prompt";
    llm-prompt.inputs.nixpkgs.follows = "nixpkgs";
    zen-browser.url = "github:MarceColl/zen-browser-flake";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    try.url = "github:edmundmiller/try";
    try.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    opencode.url = "github:anomalyco/opencode/dev";
    opencode.inputs.nixpkgs.follows = "nixpkgs";

    nix-openclaw.url = "github:openclaw/nix-openclaw";
    nix-openclaw.inputs.nixpkgs.follows = "nixpkgs";

    agent-skills.url = "github:Kyure-A/agent-skills-nix";

    # Skill sources (flake = false for hash-pinned content)
    anthropic-skills = {
      url = "github:anthropics/courses";
      flake = false;
    };
    pi-extension-skills = {
      url = "github:tmustier/pi-extensions";
      flake = false;
    };

    # NOTE: jj-spr temporarily disabled - upstream has broken cargo vendoring after flake update
    # jj-spr.url = "github:LucioFranco/jj-spr";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      flake-parts,
      nix-darwin,
      deploy-rs,
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
      # Patch openclaw-gateway to include missing docs/reference/templates (issue #18)
      # Must copy lib/openclaw (not symlink) so __dirname resolves to patched package
      openclawTemplatesOverlay = _final: prev: {
        openclaw-gateway =
          prev.runCommand "openclaw-gateway-with-templates"
            {
              inherit (prev.openclaw-gateway) meta;
              nativeBuildInputs = [ prev.makeWrapper ];
            }
            ''
              mkdir -p $out/bin $out/lib

              # Copy lib/openclaw entirely (so __dirname points here)
              cp -r ${prev.openclaw-gateway}/lib/openclaw $out/lib/
              chmod -R u+w $out/lib/openclaw

              # Add the missing templates
              mkdir -p $out/lib/openclaw/docs/reference/templates
              cp ${prev.openclaw-gateway.src}/docs/reference/templates/* $out/lib/openclaw/docs/reference/templates/

              # Add missing hasown dependency (form-data expects it)
              mkdir -p $out/lib/openclaw/node_modules/hasown
              cat > $out/lib/openclaw/node_modules/hasown/index.js <<'EOF'
              "use strict";
              module.exports = Object.hasOwn || function hasOwn(obj, prop) {
                return Object.prototype.hasOwnProperty.call(obj, prop);
              };
              EOF

              # Create new wrapper pointing to our copied dist
              makeWrapper "${prev.nodejs}/bin/node" "$out/bin/openclaw" \
                --add-flags "$out/lib/openclaw/dist/index.js" \
                --set-default OPENCLAW_NIX_MODE "1" \
                --set-default MOLTBOT_NIX_MODE "1" \
                --set-default CLAWDBOT_NIX_MODE "1"
              ln -s $out/bin/openclaw $out/bin/moltbot
            '';

        # Wrap oracle/summarize to only expose bin/ (avoid libexec/node_modules conflicts)
        oracle = prev.runCommand "oracle-bin-only" { meta = prev.oracle.meta or { }; } ''
          mkdir -p $out/bin
          ln -s ${prev.oracle}/bin/* $out/bin/
        '';
        summarize = prev.runCommand "summarize-bin-only" { meta = prev.summarize.meta or { }; } ''
          mkdir -p $out/bin
          ln -s ${prev.summarize}/bin/* $out/bin/
        '';
      };
      pkgs = mkPkgs nixpkgs [
        self.overlay
        inputs.nix-openclaw.overlays.default
        openclawTemplatesOverlay
      ] linuxSystem;
      pkgs' = mkPkgs nixpkgs-unstable [ ] linuxSystem;

      # Darwin packages
      darwinPkgs = mkPkgs nixpkgs [
        self.overlay
        inputs.nix-openclaw.overlays.default
      ] darwinSystem;

      lib = nixpkgs.lib.extend (
        self: _super: {
          my = import ./lib {
            inherit pkgs; # Linux packages for the lib functions
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
          unstable =
            if final.stdenv.isDarwin then
              mkPkgs nixpkgs-unstable [ ] final.stdenv.hostPlatform.system
            else
              pkgs';
          my = self.packages.${final.stdenv.hostPlatform.system} or { };
        };

        overlays = mapModules ./overlays import;

        packages."${linuxSystem}" = mapModules ./packages (p: pkgs.callPackage p { });
        # NOTE: jj-spr temporarily disabled - upstream has broken cargo vendoring after flake update
        packages."${darwinSystem}" = mapModules ./packages (p: darwinPkgs.callPackage p { });

        nixosModules = {
          dotfiles = import ./.;
        }
        // mapModulesRec ./modules import;

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
            isDarwin = true;
            hostName = "mactraitorpro";
          };
          modules = [
            # Set nixpkgs first, before importing modules that need it
            { nixpkgs.pkgs = darwinPkgs; }

            # Add home-manager module
            inputs.home-manager.darwinModules.home-manager

            # Add nix-homebrew module for proper homebrew management
            inputs.nix-homebrew.darwinModules.nix-homebrew

            # Add opnix for 1Password secrets integration
            inputs.opnix.darwinModules.default

            # Import the module system (provides user.packages, home.configFile, etc.)
            ./.

            # Import host-specific configuration
            ./hosts/mactraitorpro/default.nix

            # Set primary user for nix-darwin 25.05
            { system.primaryUser = "emiller"; }

            # Add openclaw to home-manager modules
            {
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.sharedModules = [
                inputs.nix-openclaw.homeManagerModules.openclaw
                inputs.agent-skills.homeManagerModules.default
              ];
            }
          ];
        };
        darwinConfigurations."Seqeratop" = nix-darwin.lib.darwinSystem {
          system = darwinSystem;
          specialArgs = {
            inherit inputs lib;
            isDarwin = true;
            hostName = "seqeratop";
          };
          modules = [
            # Set nixpkgs first, before importing modules that need it
            { nixpkgs.pkgs = darwinPkgs; }

            # Add home-manager module
            inputs.home-manager.darwinModules.home-manager

            # Add nix-homebrew module for proper homebrew management
            inputs.nix-homebrew.darwinModules.nix-homebrew

            # Add opnix for 1Password secrets integration
            inputs.opnix.darwinModules.default

            # Import the module system (provides user.packages, home.configFile, etc.)
            ./.

            # Import host-specific configuration
            ./hosts/seqeratop/default.nix

            # Set primary user for nix-darwin 25.05
            { system.primaryUser = "edmundmiller"; }

            # Add openclaw to home-manager modules
            {
              home-manager.extraSpecialArgs = { inherit inputs; };
              home-manager.sharedModules = [
                inputs.nix-openclaw.homeManagerModules.openclaw
                inputs.agent-skills.homeManagerModules.default
              ];
            }
          ];
        };

        # deploy-rs configuration
        deploy.nodes = {
          # NixOS host - remote deployment with magic rollback
          nuc = {
            hostname = "nuc";
            sshUser = "emiller";
            user = "root";
            interactiveSudo = false;
            remoteBuild = true;
            profiles.system.path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.nuc;
          };

          # Darwin hosts - local deployment only (no magic rollback on macOS)
          MacTraitor-Pro = {
            hostname = "localhost";
            profiles.system = {
              user = "emiller";
              path =
                deploy-rs.lib.aarch64-darwin.activate.custom self.darwinConfigurations."MacTraitor-Pro".system
                  "sudo ./result/sw/bin/darwin-rebuild switch --flake .#MacTraitor-Pro";
            };
          };

          Seqeratop = {
            hostname = "localhost";
            profiles.system = {
              user = "edmundmiller";
              path =
                deploy-rs.lib.aarch64-darwin.activate.custom self.darwinConfigurations."Seqeratop".system
                  "sudo ./result/sw/bin/darwin-rebuild switch --flake .#Seqeratop";
            };
          };
        };
      };
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      perSystem =
        { pkgs, system, ... }:
        {
          # Expose deploy-rs CLI for `nix run .#deploy-rs`
          packages.deploy-rs = deploy-rs.packages.${system}.default;

          treefmt = {
            projectRootFile = ".git/config";
            programs.deadnix.enable = true;
            programs.nixfmt.enable = true;
            programs.prettier.enable = true;
            programs.statix.enable = true;
          };

          # Development shell
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              nixfmt
              deadnix
              statix
              deploy-rs.packages.${system}.default
            ];
            shellHook = ''
              echo "dotfiles development shell"
            '';
          };

          # Add checks for deployment, plugins, and shell tests
          checks =
            # deploy-rs checks - validates deployment configurations (merge attrset)
            (deploy-rs.lib.${system}.deployChecks self.deploy) // {

              # zunit shell function tests
              zunit-tests =
                pkgs.runCommand "zunit-tests"
                  {
                    nativeBuildInputs = [
                      self.packages.${system}.zunit
                      pkgs.zsh
                      pkgs.git
                      pkgs.gnused
                      pkgs.bash
                    ];
                  }
                  ''
                    # Setup git config for tests
                    export HOME=$TMPDIR
                    git config --global user.email "test@test.com"
                    git config --global user.name "Test User"
                    git config --global init.defaultBranch main

                    # Run zunit tests (--tap bypasses revolver spinner dependency)
                    cd ${./.}
                    for test in config/*/tests/*.zunit; do
                      if [ -f "$test" ]; then
                        echo "Running $test..."
                        zunit --tap "$test"
                      fi
                    done

                    # Create success marker
                    mkdir -p $out
                    echo "All zunit tests passed" > $out/result
                  '';

              validate-claude-plugins =
                pkgs.runCommand "validate-claude-plugins"
                  {
                    buildInputs = [ pkgs.python312 ];
                  }
                  ''
                    # Create a temporary directory for the check
                    mkdir -p $out

                    # Copy plugin files to temporary location
                    cp -r ${./.} /tmp/dotfiles-check
                    cd /tmp/dotfiles-check

                    # Install uv
                    export HOME=/tmp
                    ${pkgs.curl}/bin/curl -LsSf https://astral.sh/uv/install.sh | sh
                    export PATH="$HOME/.cargo/bin:$PATH"

                    # Run claudelint on each plugin directory
                    echo "Validating Claude Code plugins..."

                    for plugin in config/claude/plugins/*/; do
                      if [ -d "$plugin" ]; then
                        echo "Checking $plugin..."
                        uvx claudelint "$plugin" || exit 1
                      fi
                    done

                    # Create success marker
                    echo "All plugins validated successfully" > $out/result
                  '';
            };
        };
    };
}
