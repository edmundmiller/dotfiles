# NixOS VM smoke test for the kittylitter module.
#
# Exercises the NixOS/home-manager integration: the module should generate
# host.toml, install the user systemd unit, start the daemon, and expose a
# working local CLI status path.
{
  pkgs,
  inputs,
  kittylitterPackage,
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

  nixosTesting = import "${pkgs.path}/nixos/lib/testing-python.nix" {
    inherit pkgs;
    inherit (pkgs.stdenv.hostPlatform) system;
  };
in
nixosTesting.runTest {
  name = "kittylitter-module";

  node.specialArgs = {
    lib = dotfilesLib;
    inherit inputs;
    isDarwin = false;
  };

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
        ../default.nix
      ];

      nixpkgs.config.allowUnfree = true;

      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
        group = "users";
        home = "/home/alice";
        createHome = true;
      };

      home-manager.useGlobalPkgs = true;
      home-manager.users.alice.home.stateVersion = "25.11";

      modules.services.kittylitter = {
        enable = true;
        package = kittylitterPackage;
        user = "alice";
        homeDir = "/home/alice";
        enabledAgents = [
          "pi"
          "hermes"
        ];
      };

      # Keep the smoke test focused on module wiring and daemon startup.
      # The CLI availability checks should therefore be deterministic.
      environment.systemPackages = [ pkgs.jq ];
      virtualisation.memorySize = 2048;
    };

  testScript = ''
    import json

    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("home-manager-alice.service")

    with subtest("home-manager installs and enables the user unit"):
        machine.succeed("test -L /home/alice/.config/systemd/user/kittylitter.service")
        unit = machine.succeed("readlink -f /home/alice/.config/systemd/user/kittylitter.service")
        assert "kittylitter.service" in unit

    with subtest("kittylitter user service starts"):
        machine.succeed("loginctl enable-linger alice")
        machine.succeed("systemctl start user@1000.service")
        machine.wait_for_unit("user@1000.service")
        machine.wait_until_succeeds(
            "runuser -u alice -- env XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-active kittylitter.service"
        )

    with subtest("kittylitter config is generated from the Nix module"):
        machine.succeed("test -f /home/alice/.config/kittylitter/host.toml")
        config = machine.succeed("cat /home/alice/.config/kittylitter/host.toml")
        assert "[agents.pi]" in config
        assert "enabled = true" in config
        assert "[agents.hermes]" in config
        assert "[agents.codex]" in config
        assert "enabled = false" in config
        assert "replay_max_msgs = 2048" in config

    with subtest("daemon status works through the managed CLI"):
        status_raw = machine.succeed(
            "runuser -u alice -- env HOME=/home/alice XDG_CONFIG_HOME=/home/alice/.config XDG_RUNTIME_DIR=/run/user/1000 kittylitter status --json"
        )
        status = json.loads(status_raw)
        assert status["config_path"] == "/home/alice/.config/kittylitter/host.toml"
        agents = {agent["name"]: agent for agent in status["agents"]}
        for agent_name in ["pi", "hermes", "codex"]:
            assert agent_name in agents
            assert isinstance(agents[agent_name]["available"], bool)

    with subtest("pair payload and agent listing commands are usable"):
        pair = machine.succeed(
            "runuser -u alice -- env HOME=/home/alice XDG_CONFIG_HOME=/home/alice/.config XDG_RUNTIME_DIR=/run/user/1000 kittylitter pair"
        )
        assert "node" in pair.lower() or "token" in pair.lower()
        agents_list = machine.succeed(
            "runuser -u alice -- env HOME=/home/alice XDG_CONFIG_HOME=/home/alice/.config XDG_RUNTIME_DIR=/run/user/1000 kittylitter agents list"
        )
        assert "pi" in agents_list
  '';
}
