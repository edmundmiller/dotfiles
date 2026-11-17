{ pkgs, inputs }:
let
  lib = pkgs.lib.extend (
    self: _super: {
      my = import ../../../../lib {
        inherit pkgs inputs;
        lib = self;
      };
    }
  );
  evaluate =
    alerting:
    (lib.evalModules {
      specialArgs = {
        inherit pkgs lib;
        isDarwin = false;
      };
      modules = [
        ../default.nix
        ({ lib, ... }: {
          options = {
            systemd.services = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
            };
            systemd.timers = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
            };
            networking.firewall.interfaces = lib.mkOption {
              type = lib.types.attrsOf lib.types.anything;
              default = { };
            };
            assertions = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [ ];
            };
            modules.services = {
              homepage.enable = lib.my.mkBoolOpt false;
              obsidian-sync = {
                enable = lib.my.mkBoolOpt false;
                healthcheck.enable = lib.my.mkBoolOpt false;
                healthcheck.pingUrl = lib.my.mkOpt lib.types.str "";
              };
              hass = {
                enable = lib.my.mkBoolOpt true;
              }
              // lib.my.mkRegistry {
                gatus = {
                  name = "Home Assistant Runtime";
                  group = "Smart Home";
                  url = "http://127.0.0.1:8124/health";
                  interval = "60s";
                  conditions = [ "[STATUS] == 200" ];
                  alerts = true;
                };
              };
            };
          };
          config.modules.services.gatus = {
            enable = true;
            inherit alerting;
          };
        })
      ];
    }).config;
  enabled = evaluate {
    email = {
      enable = true;
      url = "https://worker.example.test/email";
      tokenFile = toString (pkgs.writeText "fixture-mail-api" "email-api-fixture-secret");
      ingestTokenFile = toString (pkgs.writeText "fixture-mail-ingest" "email\"slash\\and&pipe|dollar$");
    };
    notion = {
      enable = true;
      tokenFile = toString (pkgs.writeText "fixture-api" "api-fixture-secret");
      ingestTokenFile = toString (pkgs.writeText "fixture-ingest" "ingest-fixture-secret");
      dataSourceId = "source";
      evidenceUrl = "https://gatus.example.test/";
    };
  };
  disabled = evaluate { };
  emailOnly = evaluate { email = enabled.modules.services.gatus.alerting.email; };
  notionOnly = evaluate { notion = enabled.modules.services.gatus.alerting.notion; };
  invalid = evaluate {
    email.enable = true;
    notion.enable = true;
  };
  fixtures = pkgs.writeText "gatus-alerting-fixtures.json" (
    builtins.toJSON {
      enabled = {
        prepare = enabled.systemd.services.gatus.serviceConfig.ExecStartPre;
        notion = enabled.systemd.services.gatus-notion.serviceConfig;
        email = enabled.systemd.services.gatus-email.serviceConfig;
        assertions = map (item: item.assertion) enabled.assertions;
      };
      emailOnly.prepare = emailOnly.systemd.services.gatus.serviceConfig.ExecStartPre;
      notionOnly.prepare = notionOnly.systemd.services.gatus.serviceConfig.ExecStartPre;
      disabled = {
        prepare = disabled.systemd.services.gatus.serviceConfig.ExecStartPre;
        hasNotionService = disabled.systemd.services ? gatus-notion;
        hasEmailService = disabled.systemd.services ? gatus-email;
        assertions = map (item: item.assertion) disabled.assertions;
      };
      invalidAssertions = map (item: item.assertion) invalid.assertions;
    }
  );
in
pkgs.runCommand "gatus-alerting-tests"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.gatus
    ];
  }
  ''
    export PYTHONDONTWRITEBYTECODE=1
    export GATUS_CONFIG_FIXTURES=${fixtures}
    export GATUS_BINARY=${pkgs.gatus}/bin/gatus
    python3 ${./test_notion_incidents.py} ${../incident-delivery.py} -v
    touch "$out"
  ''
