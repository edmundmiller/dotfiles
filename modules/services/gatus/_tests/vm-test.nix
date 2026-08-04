# NixOS VM test: Gatus renders the registry into a config it actually accepts.
#
# The registry indirection (modules.services.<name>.registry.gatus, aggregated
# by ../default.nix) is only half-covered by pure eval: eval proves the endpoint
# attrset is shaped right, not that Gatus parses the rendered YAML or that the
# ExecStartPre secret-substitution leaves a valid config behind. This boots the
# real unit and asserts both.
#
# Run: nix build .#checks.x86_64-linux.vm-services-gatus-vm-test
# (requires x86_64-linux — run on NUC or Linux builder)
{ pkgs, inputs }:
let
  dotfilesLib = pkgs.lib.extend (
    self: _super: {
      my = import ../../../../lib {
        inherit pkgs inputs;
        lib = self;
      };
    }
  );
in
dotfilesLib.my.mkServiceVmTest {
  name = "gatus-registry";

  modules = [
    ../default.nix

    # gatus/default.nix still hardcodes entries for these two, so it reads
    # their options directly. Declare just the paths it touches; both stay
    # disabled so no extra endpoints appear.
    (
      { lib, ... }:
      {
        options.modules.services.homepage.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        options.modules.services.obsidian-sync = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          healthcheck.enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          healthcheck.pingUrl = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
        };
      }
    )

    # Two synthetic services that contribute registry entries exactly the way
    # real service modules do. Using stand-ins rather than a real module keeps
    # the test hermetic (no agenix secrets, no docker, no home-manager) and
    # lets it assert the enable-gating in both directions. That the real
    # modules produce byte-identical aggregator output is proven separately by
    # the golden eval diff.
    (
      { lib, ... }:
      {
        options.modules.services.registry-on = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
        }
        // dotfilesLib.my.mkRegistry {
          gatus = {
            name = "Registry On";
            group = "TestGroup";
            url = "http://localhost:8084/health";
            conditions = [ "[STATUS] == 200" ];
          };
        };

        options.modules.services.registry-off = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
        }
        // dotfilesLib.my.mkRegistry {
          gatus = {
            name = "Registry Off";
            group = "TestGroup";
            url = "http://localhost:9/never";
            conditions = [ "[STATUS] == 200" ];
          };
        };
      }
    )
  ];

  extraConfig = {
    modules.services.gatus.enable = true;

    modules.services.registry-on.enable = true;
    modules.services.registry-off.enable = false;

    # The module guards this endpoint on a readable key file existing.
    modules.services.gatus.healthchecks.readonlyApiKeyFile = "/etc/gatus-test-key";
    environment.etc."gatus-test-key".text = "test-api-key";

    # The test script curls the local API; a bare NixOS node does not put
    # curl on PATH.
    environment.systemPackages = [ pkgs.curl ];
  };

  testScript = ''
    import json

    start_all()
    machine.wait_for_unit("gatus.service")

    with subtest("gatus serves its health endpoint"):
        machine.wait_until_succeeds("curl -fsS http://localhost:8084/health", timeout=60)

    with subtest("the rendered config is what Gatus parsed, secrets substituted"):
        # ExecStartPre copies the template to /run and seds secrets in. If that
        # left a broken file, gatus.service would not have reached "active".
        config = machine.succeed("cat /run/gatus/config.yaml")
        assert "__HEALTHCHECKS_API_KEY__" not in config, (
            f"secret placeholder survived into the running config:\n{config}"
        )

    with subtest("registry-derived endpoints reach the running Gatus"):
        # "Registry On" is nowhere in gatus/default.nix. It appears only
        # because its module declares registry.gatus, so seeing it in the
        # running daemon proves the aggregation path works end-to-end.
        raw = machine.succeed("curl -fsS http://localhost:8084/api/v1/endpoints/statuses")
        names = {e["name"] for e in json.loads(raw)}
        print(sorted(names))
        assert "Registry On" in names, (
            f"registry endpoint missing from the running Gatus: {sorted(names)}"
        )

    with subtest("a disabled service contributes no endpoint"):
        # Guard the guard: if entries were emitted unconditionally, the
        # assertion above would pass without the enable check working.
        assert "Registry Off" not in names, (
            f"endpoint from a disabled module leaked into the config: {sorted(names)}"
        )
  '';
}
