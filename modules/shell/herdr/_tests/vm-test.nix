# NixOS VM test: the config Herdr actually runs with must pass `herdr config check`.
#
# The template is validated separately by _tests/config-check.nix. This test
# covers what that cannot: `home.activation.herdr-config-bootstrap` copies the
# template to a writable ~/.config/herdr/config.toml and then upserts managed
# keybindings/theme into it with python. Those upserts, not just the template,
# are what produce the file Herdr parses -- so drift there (an unknown key such
# as the stale `ui.agent_panel_scope`) is only observable post-activation.
#
# `herdr config check` takes no path argument; it reads
# $XDG_CONFIG_HOME/herdr/config.toml and exits non-zero on unknown keys.
{
  pkgs,
  inputs,
  herdrPackage,
}:
let
  dotfilesLib = pkgs.lib.extend (
    self: _super: {
      my = import ../../../../lib {
        inherit pkgs inputs;
        lib = self;
      };
    }
  );

  # Same harness as modules/services/kittylitter/_tests/vm-test.nix.
  # `pkgs.testers.runNixOSTest` pins nixpkgs.config itself, which conflicts
  # with the per-node overlay/allowUnfree this module's package needs.
  nixosTesting = import "${pkgs.path}/nixos/lib/testing-python.nix" {
    inherit pkgs;
    inherit (pkgs.stdenv.hostPlatform) system;
  };
in
nixosTesting.runTest {
  name = "herdr-config-check";

  node.specialArgs = {
    lib = dotfilesLib;
    inherit inputs;
    isDarwin = false;
  };

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
        # The module consumes dotfiles-custom options (env, home.configFile,
        # user.*) that a bare NixOS VM does not define.
        ../../../options.nix
        # Declare only the surface modules/shell/herdr reads from sibling
        # modules, rather than importing them and their dependency trees.
        # Assigning these without declaring them is an "option does not exist"
        # error. Every `modules.agents.*` reference is guarded by a
        # `cfg.integrations.<name>.enable &&`, so the integrations disabled
        # below short-circuit those; the git theme options are read
        # unconditionally and must exist.
        (
          { lib, ... }:
          {
            options.modules.shell.tmux = {
              enable = lib.mkEnableOption "tmux";
              rcFiles = lib.mkOption {
                type = lib.types.listOf (lib.types.either lib.types.path lib.types.str);
                default = [ ];
              };
            };

            options.modules.shell.git.hunk.theme = {
              dark = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              light = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
            };
          }
        )
        ../default.nix
      ];

      nixpkgs = {
        config.allowUnfree = true;
        overlays = [
          inputs.llm-agents.overlays."shared-nixpkgs"
          # Provides `pkgs.my` (rift, herdr), which the module reads. The
          # check's own outer `pkgs` does not carry it.
          inputs.self.overlays.default
        ];
      };

      home-manager.useGlobalPkgs = true;
      # home.stateVersion is already set by modules/options.nix.

      # Isolate the activation under test. Enabling Herdr also registers
      # activation entries that shell out to `herdr plugin install` and friends,
      # which fetch from GitHub -- no network in the VM, so
      # home-manager-alice.service would fail before `config check` ever runs.
      # Only herdr-config-bootstrap produces the config this test asserts on.
      home-manager.users.alice =
        { lib, ... }:
        {
          home.activation.herdr-plugin-registry = lib.mkForce (
            lib.hm.dag.entryAfter [ "writeBoundary" ] ": skipped in VM test"
          );
          home.activation.herdr-smart-rename = lib.mkForce (
            lib.hm.dag.entryAfter [ "writeBoundary" ] ": skipped in VM test"
          );
          home.activation.herdr-marketplace-plugins = lib.mkForce (
            lib.hm.dag.entryAfter [ "writeBoundary" ] ": skipped in VM test"
          );
          home.activation.herdr-agent-integrations = lib.mkForce (
            lib.hm.dag.entryAfter [ "writeBoundary" ] ": skipped in VM test"
          );
        };

      # The dotfiles `user` abstraction is separate from `users.users`, and
      # modules/options.nix derives users.users.<name> from it. Setting
      # users.users.alice directly here would conflict with that. It defaults
      # to "emiller" under root eval, which would attach the Herdr activation
      # to home-manager.users.emiller while this test drives alice.
      # mkForce: `user` is a plain attrs option, so this merges with the
      # options.nix definition and would otherwise collide on `name`.
      user = lib.mkForce {
        name = "alice";
        description = "Test user";
        home = "/home/alice";
        uid = 1000;
        group = "users";
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
      users.users.alice.createHome = true;

      # modules/shell/herdr reads config.modules.shell.tmux.enable for its
      # optional popup integration; only the herdr module is imported here.
      modules.shell.tmux.enable = false;

      modules.shell.herdr.enable = true;
      # Keep the harness minimal: each integration reaches into a
      # `modules.agents.*` / `modules.services.*` module that is not imported
      # here. They default to true, and disabling them short-circuits those
      # references. Config validity does not depend on them.
      modules.shell.herdr.integrations = {
        pi.enable = false;
        claude.enable = false;
        codex.enable = false;
        opencode.enable = false;
        omp.enable = false;
        droid.enable = false;
        hermes.enable = false;
      };
      # Pin the template explicitly. The module default points at
      # `${config.dotfiles.configDir}/herdr/config.toml`, a runtime checkout
      # path the VM never deploys, so activation would bootstrap from a
      # missing file instead of the tracked template this test targets.
      modules.shell.herdr.configFile = ../../../../config/herdr/config.toml;

      virtualisation.memorySize = 2048;
    };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-alice.service")

    # Call the binary by store path: `runuser` starts no login shell, so
    # neither Alice's home-manager profile nor /run/current-system/sw is
    # guaranteed on PATH. Otherwise this would assert "command not found".
    herdr = "${herdrPackage}/bin/herdr"
    as_alice = (
        "runuser -u alice -- env HOME=/home/alice "
        "XDG_CONFIG_HOME=/home/alice/.config "
    )

    with subtest("the herdr binary under test is executable"):
        machine.succeed(f"test -x {herdr}")
        print(machine.succeed(f"{herdr} --version"))

    with subtest("bootstrap creates a writable config, not a store symlink"):
        machine.succeed("test -f /home/alice/.config/herdr/config.toml")
        machine.fail("test -L /home/alice/.config/herdr/config.toml")
        machine.succeed("runuser -u alice -- test -w /home/alice/.config/herdr/config.toml")

    with subtest("herdr config check accepts the activated config"):
        # The real assertion: the post-activation file Herdr parses is clean.
        status, out = machine.execute(as_alice + f"{herdr} config check 2>&1")
        print(out)
        assert status == 0, f"herdr config check rejected the activated config:\n{out}"

    with subtest("herdr config check still rejects unknown keys"):
        # Guard the guard: if `config check` stopped flagging unknown keys, the
        # subtest above would pass for any config at all.
        machine.succeed(
            "cp /home/alice/.config/herdr/config.toml /tmp/herdr-config.bak"
        )
        # Insert under the existing [ui] header rather than appending a second
        # one: a duplicate table is a TOML parse error, which would make this
        # subtest pass without proving unknown-key detection at all.
        machine.succeed(
            "grep -q '^\\[ui\\]' /home/alice/.config/herdr/config.toml"
        )
        machine.succeed(
            "sed -i '0,/^\\[ui\\]/s//[ui]\\nherdr_vm_canary = \"x\"/'"
            " /home/alice/.config/herdr/config.toml"
        )
        machine.succeed(
            "grep -q 'herdr_vm_canary' /home/alice/.config/herdr/config.toml"
        )
        status, out = machine.execute(as_alice + f"{herdr} config check 2>&1")
        print(out)
        assert status != 0, (
            "herdr config check accepted an unknown key, so it cannot detect "
            f"config drift:\n{out}"
        )
        machine.succeed(
            "cp /tmp/herdr-config.bak /home/alice/.config/herdr/config.toml"
        )
  '';
}
