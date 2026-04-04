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
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";

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

    # Restrict flake systems to the architectures this repo actually targets.
    systems = {
      url = "path:./systems";
      flake = false;
    };

    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.inputs.systems.follows = "systems";

    # Keep an upstream-shaped llm-agents input for Hermes specifically so we
    # can use Numtide's exact packaged derivation and maximize binary-cache
    # hits instead of rebuilding against our repo-wide nixpkgs follow.
    llm-agents-upstream = {
      url = "github:numtide/llm-agents.nix/8945761bf8e462e15b3b76f1a38511f9b809619d";
      inputs.systems.follows = "systems";
    };

    # Canonical authoring/runtime repo for agent specs, renderers, and
    # reusable OpenClaw defaults.
    # Note: while actively iterating locally, flake.lock may intentionally pin
    # this input to /Users/emiller/src/personal/openclaw-workspace so deploys
    # use unpublished local workspace changes directly.
    openclaw-workspace = {
      url = "git+ssh://git@github.com/edmundmiller/openclaw-workspace";
      inputs.hermesAgent.follows = "hermesAgent";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.llm-agents.follows = "llm-agents";
    };

    nix-steipete-tools.url = "github:openclaw/nix-steipete-tools";
    nix-steipete-tools.inputs.nixpkgs.follows = "nixpkgs";

    google-workspace-cli.url = "github:googleworkspace/cli";

    # Expose Hermes as a first-class root input so infra can override the
    # upstream package directly when openclaw-workspace's wrapper module needs
    # a local patch before upstream merges.
    hermesAgent = {
      # Keep the packaged Hermes source aligned with the existing upstream pin
      # from openclaw-workspace, then layer only the local fallback fix patch
      # on top.
      url = "github:NousResearch/hermes-agent/abf1e98f6253f6984479fe03d1098173a9b065a7";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Agent skills catalog (child flake). Owns agent-skills-nix + remote skill source pins.
    skills-catalog = {
      url = "path:./skills";
      inputs.nixpkgs.follows = "nixpkgs";
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
      pkgs = mkPkgs nixpkgs [
        self.overlays.default
        inputs.llm-agents.overlays.default
      ] linuxSystem;
      pkgs' = mkPkgs nixpkgs-unstable [ ] linuxSystem;

      # Darwin packages
      darwinPkgs = mkPkgs nixpkgs [
        self.overlays.default
        inputs.llm-agents.overlays.default
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
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks.flakeModule
      ];

      flake = {
        lib = lib.my;

        overlays = mapModules ./overlays import // {
          default = final: _prev: {
            unstable =
              if final.stdenv.isDarwin then
                mkPkgs nixpkgs-unstable [ ] final.stdenv.hostPlatform.system
              else
                pkgs';
            my = self.packages.${final.stdenv.hostPlatform.system} or { };
          };
        };

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
                inputs.skills-catalog.homeManagerModules.default
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
                inputs.skills-catalog.homeManagerModules.default
              ];
            }
          ];
        };

        # deploy-rs configuration
        deploy.nodes = {
          # NixOS hosts - remote deployment with magic rollback
          nuc = {
            hostname = "nuc";
            sshUser = "emiller";
            user = "root";
            interactiveSudo = false;
            remoteBuild = true;
            profiles.system.path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.nuc;
          };

          unas = {
            hostname = "192.168.1.101";
            sshUser = "emiller";
            user = "root";
            interactiveSudo = false;
            remoteBuild = true;
            profiles.system.path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.unas;
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
      systems = lib.mkForce [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          # Expose deploy-rs CLI for `nix run .#deploy-rs`
          packages.deploy-rs = deploy-rs.packages.${system}.default;

          # Headless agent environment (Factory, Devin, etc.)
          # Install: nix profile install .#agent-env
          # Shell:   nix develop .#agent
          packages.agent-env = pkgs.buildEnv {
            name = "dotfiles-agent-env";
            paths = with pkgs; [
              # VCS
              git
              jujutsu
              gh

              # Shell essentials
              zsh
              tmux
              direnv
              nix-direnv
              starship

              # Search & navigation
              ripgrep
              fd
              fzf
              bat
              eza
              zoxide
              jq
              delta

              # Build tools
              gnumake
              just
            ];
          };

          treefmt = {
            projectRootFile = ".git/config";
            programs = {
              deadnix.enable = true;
              nixfmt.enable = true;
              prettier.enable = true;
              statix.enable = true;
            };
            settings.global.excludes = [
              "packages/*/dist/**"
              "packages/*/node_modules/**"
              ".beads/backup/**"
            ];
          };

          pre-commit.settings = {
            hooks = {
              treefmt = {
                enable = true;
                package = config.treefmt.build.wrapper;
              };
              beads = {
                enable = true;
                name = "beads";
                entry = "bd hooks run pre-commit";
                language = "system";
                pass_filenames = false;
                stages = [ "pre-push" ];
              };
              ha-automation-assertions = {
                enable = true;
                name = "ha-automation-assertions";
                entry = toString (
                  pkgs.writeShellScript "ha-automation-assertions" ''
                    failures=$(nix eval '.#checks.${system}.ha-automation-assertions.passthru.failures' --json 2>/dev/null)
                    if [ "$failures" != "[]" ]; then
                      echo "HA automation assertions failed:" >&2
                      echo "$failures" | ${pkgs.jq}/bin/jq -r '.[].msg' | sed 's/^/  FAIL: /' >&2
                      exit 1
                    fi
                  ''
                );
                language = "system";
                pass_filenames = false;
                files = "modules/services/hass/";
                stages = [ "pre-push" ];
              };
              ha-apply-devices-assertions = {
                enable = true;
                name = "ha-apply-devices-assertions";
                entry = toString (
                  pkgs.writeShellScript "ha-apply-devices-assertions" ''
                    failures=$(nix eval '.#checks.${system}.ha-apply-devices-assertions.passthru.failures' --json 2>/dev/null)
                    if [ "$failures" != "[]" ]; then
                      echo "HA apply-devices assertions failed:" >&2
                      echo "$failures" | ${pkgs.jq}/bin/jq -r '.[].msg' | sed 's/^/  FAIL: /' >&2
                      exit 1
                    fi
                  ''
                );
                language = "system";
                pass_filenames = false;
                files = "modules/services/hass/";
                stages = [ "pre-push" ];
              };
              skills-lock-sync = {
                enable = true;
                name = "skills-lock-sync";
                entry = toString (
                  pkgs.writeShellScript "skills-lock-sync" ''
                                                          set -euo pipefail

                                                          upstream=""
                                                          if upstream_ref=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
                                                            upstream="$upstream_ref"
                                                          elif git rev-parse --verify origin/main >/dev/null 2>&1; then
                                                            upstream="origin/main"
                                                          else
                                                            echo "skills-lock-sync: no upstream branch found; skipping check" >&2
                                                            exit 0
                                                          fi

                                                          range="$upstream...HEAD"
                                                          changed_files=$(git diff --name-only "$range")

                                                          if ! echo "$changed_files" | grep -q '^config/agents/skills/'; then
                                                            exit 0
                                                          fi

                                                          has_parent_lock=0
                                                          has_child_lock=0

                                                          if echo "$changed_files" | grep -q '^flake.lock$'; then
                                                            has_parent_lock=1
                                                          fi

                                                          if echo "$changed_files" | grep -q '^skills/flake.lock$'; then
                                                            has_child_lock=1
                                                          fi

                                                          if [ "$has_parent_lock" -eq 1 ] && [ "$has_child_lock" -eq 1 ]; then
                                                            exit 0
                                                          fi

                                                          cat >&2 <<'EOF'
                                        ERROR: config/agents/skills changes detected without synced lock files.

                                        Run:
                                          hey skills-sync

                                        This updates:
                                          - skills/flake.lock (dotfiles-repo pin)
                                          - flake.lock (skills-catalog sync)
                    and rebuilds so shared skills are refreshed everywhere.
                                        EOF
                                                          exit 1
                  ''
                );
                language = "system";
                pass_filenames = false;
                always_run = true;
                stages = [
                  "pre-commit"
                  "pre-push"
                ];
              };
              jscpd = {
                enable = true;
                name = "jscpd";
                description = "Detect duplicate code in TypeScript, JavaScript, and Nix files";
                entry = toString (
                  pkgs.writeShellScript "jscpd-check" ''
                    set -euo pipefail

                    # Check if npx is available
                    if ! command -v npx &> /dev/null; then
                      echo "Warning: npx not found, skipping jscpd check" >&2
                      exit 0
                    fi

                    # Run jscpd and capture output
                    echo "Running duplicate code detection..."
                    if npx -y jscpd@4.0.5 . --config .jscpd.json; then
                      echo "✓ No significant code duplication detected"
                      exit 0
                    else
                      echo "✗ Code duplication detected above threshold" >&2
                      echo "Run 'npx jscpd . --config .jscpd.json' to see details" >&2
                      exit 1
                    fi
                  ''
                );
                language = "system";
                pass_filenames = false;
                files = "\\.(ts|js|nix)$";
                stages = [ "pre-push" ];
              };
              large-file-detection = {
                enable = true;
                name = "large-file-detection";
                description = "Reject files over 500KB (excludes lock files and known large files)";
                entry = toString (
                  pkgs.writeShellScript "large-file-check" ''
                    set -euo pipefail
                    MAX_SIZE=512000  # 500KB in bytes
                    failed=0
                    for file in "$@"; do
                      # Skip lock files and known large files
                      case "$file" in
                        *.lock|flake.lock|*package-lock.json|yarn.lock|pnpm-lock.yaml|config/qutebrowser/css/github.com) continue ;;
                        *.png|*.jpg|*.jpeg|*.gif|*.ico|*.svg) continue ;;
                      esac
                      if [ -f "$file" ]; then
                        size=$(wc -c < "$file")
                        if [ "$size" -gt "$MAX_SIZE" ]; then
                          echo "ERROR: $file is $(( size / 1024 ))KB (limit: 500KB)" >&2
                          failed=1
                        fi
                      fi
                    done
                    exit $failed
                  ''
                );
                language = "system";
                stages = [ "pre-commit" ];
              };
              tech-debt-tracking = {
                enable = true;
                name = "tech-debt-tracking";
                description = "Report TODO/FIXME/HACK comments for tech debt awareness";
                entry = toString (
                  pkgs.writeShellScript "tech-debt-report" ''
                    set -uo pipefail
                    matches=$(${pkgs.ripgrep}/bin/rg --no-heading -n 'TODO|FIXME|HACK' "$@" 2>/dev/null || true)
                    if [ -n "$matches" ]; then
                      echo "📋 Tech debt markers found in staged files:"
                      echo "$matches"
                      echo ""
                      echo "Consider filing issues for high-priority items."
                    fi
                    # Always succeed — this is informational only
                    exit 0
                  ''
                );
                language = "system";
                types = [ "text" ];
                stages = [ "pre-commit" ];
              };
            };
          };

          # Headless agent dev shell (nix develop .#agent)
          devShells.agent = pkgs.mkShell {
            packages = self.packages.${system}.agent-env.paths;
            shellHook = ''
              echo "dotfiles agent shell (headless)"
            '';
          };

          # Development shell
          devShells.default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                nixfmt
                deadnix
                statix
                deploy-rs.packages.${system}.default
              ]
              ++ config.pre-commit.settings.enabledPackages;
            shellHook = config.pre-commit.shellHook + ''
              echo "dotfiles development shell"
            '';
          };

          # Add checks for deployment, plugins, and shell tests
          checks =
            # deploy-rs checks - validates deployment configurations (merge attrset)
            (deploy-rs.lib.${system}.deployChecks self.deploy)
            // {

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
                      pkgs.sesh
                      pkgs.fzf
                      pkgs.zoxide
                      pkgs.tmux
                    ];
                  }
                  ''
                    # Setup git config for tests
                    export HOME=$TMPDIR
                    git config --global user.email "test@test.com"
                    git config --global user.name "Test User"
                    git config --global init.defaultBranch main

                    # Start a headless tmux server on the default socket
                    export TMUX_TMPDIR=$TMPDIR
                    tmux new-session -d -s ci-session 2>/dev/null || true
                    # Mark as headless so popup test stays skipped
                    export ZUNIT_HEADLESS=1

                    # Seed zoxide database in writable temp storage
                    export _ZO_DATA_DIR=$TMPDIR/zoxide-data
                    mkdir -p "$_ZO_DATA_DIR"
                    ZOXIDE_TEST_DIRS="$TMPDIR/zunit-zoxide-$$"
                    mkdir -p "$ZOXIDE_TEST_DIRS/code/project1" \
                              "$ZOXIDE_TEST_DIRS/code/project2" \
                              "$ZOXIDE_TEST_DIRS/repos/work"
                    zoxide add "$ZOXIDE_TEST_DIRS/code/project1" 2>/dev/null || true
                    zoxide add "$ZOXIDE_TEST_DIRS/code/project2" 2>/dev/null || true
                    zoxide add "$ZOXIDE_TEST_DIRS/repos/work" 2>/dev/null || true
                    export ZOXIDE_TEST_DIRS

                    # Run zunit tests (--tap bypasses revolver spinner dependency)
                    cd ${./.}
                    for test in config/*/tests/*.zunit; do
                      if [ -f "$test" ]; then
                        echo "Running $test..."
                        zunit --tap "$test"
                      fi
                    done

                    # Cleanup
                    tmux -L default kill-server 2>/dev/null || true
                    rm -rf $ZOXIDE_TEST_DIRS 2>/dev/null || true

                    # Create success marker
                    mkdir -p $out
                    echo "All zunit tests passed" > $out/result
                  '';

              dagster-package =
                pkgs.runCommand "dagster-package-check"
                  {
                    nativeBuildInputs = [ self.packages.${system}.dagster ];
                  }
                  ''
                    echo "Checking dagster binaries..."
                    dagster --version
                    dagster-webserver --help > /dev/null
                    dagster-daemon --help > /dev/null
                    dagster-graphql --help > /dev/null

                    echo "Checking python imports..."
                    python3 -c "import dagster; print(f'dagster {dagster.__version__}')"
                    python3 -c "import dagster_postgres; print('dagster_postgres OK')"
                    python3 -c "import dagster_webserver; print('dagster_webserver OK')"
                    python3 -c "import dagster_graphql; print('dagster_graphql OK')"

                    mkdir -p $out
                    echo "All dagster checks passed" > $out/result
                  '';

              # HA config validation is now done at build time on the NUC via
              # validate-config.nix (uses HA's own check_config). The JSON schema
              # in schemas/adaptive-lighting.json is kept as agent reference only.

              # Pure Nix eval: assert structural properties of HA automation config.
              # Catches regressions like removed time guards without a VM.
              ha-automation-assertions = import ./modules/services/hass/_tests/eval-automations.nix {
                nixosConfig = self.nixosConfigurations.nuc;
                inherit pkgs;
              };

              # Pure Nix eval: assert hass-apply-devices stays deploy-safe.
              ha-apply-devices-assertions = import ./modules/services/hass/_tests/eval-apply-devices.nix {
                nixosConfig = self.nixosConfigurations.nuc;
                inherit pkgs;
              };
            }
            // lib.optionalAttrs (system == "x86_64-linux") {
              # NixOS VM test: boot HA with our domain modules, verify config + API.
              # Only on x86_64-linux (needs QEMU). Run on NUC or Linux builder.
              hass-vm-test = import ./modules/services/hass/_tests/vm-test.nix {
                inherit pkgs;
              };

              # Time-guard behavior tests: verify automations block before 7 AM.
              # Uses clock manipulation + HA API to test end-to-end.
              hass-time-guards = import ./modules/services/hass/_tests/time-guards-test.nix {
                inherit pkgs;
              };

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
