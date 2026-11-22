# Imported explicitly by default.nix; exclude from recursive module discovery.
{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
let
  cfg = config.services.home-assistant;
  health = config.modules.services.hass.healthcheck;
  domains = [
    "automation"
    "script"
    "scene"
  ];
  domainOf = key: builtins.head (lib.splitString " " key);
  reloadable = key: builtins.elem (domainOf key) domains;
  domainConfig = domain: lib.filterAttrs (key: _: domainOf key == domain) cfg.config;
  manifest = pkgs.writeText "hass-reload-domains.json" (
    builtins.toJSON {
      version = 1;
      domains = lib.genAttrs domains (
        domain:
        let
          value = domainConfig domain;
        in
        if value == { } then null else builtins.hashString "sha256" (builtins.toJSON value)
      );
    }
  );
  core = pkgs.writeText "hass-restart-config.json" (
    builtins.toJSON {
      config = lib.filterAttrs (key: _: !reloadable key) cfg.config;
      inherit (cfg) themes;
    }
  );
in
{
  config = lib.optionalAttrs (!isDarwin) (
    lib.mkIf (config.modules.services.hass.enable && health.enable) {
      assertions = [
        {
          assertion = cfg.config != null && !cfg.configWritable;
          message = "HA deployment reloads require the Nix-owned configuration.yaml symlink.";
        }
      ];

      # Keep SIGHUP unchanged. Only these domains can change without changing
      # the HA unit. Packages, core YAML, themes and Lovelace still require it.
      systemd.services.home-assistant.reloadTriggers = lib.mkForce (
        [ core ]
        ++ lib.optional (
          cfg.lovelaceConfig != null || cfg.lovelaceConfigFile != null
        ) config.environment.etc."home-assistant/ui-lovelace.yaml".source
      );

      systemd.services.hass-reload-config = {
        description = "Apply changed HA automations, scripts and scenes without restarting HA";
        wantedBy = [ "multi-user.target" ];
        after = [ "home-assistant.service" ];
        wants = [ "home-assistant.service" ];
        restartTriggers = [ manifest ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "hass-reload-config";
          StateDirectoryMode = "0700";
          DynamicUser = true;
          LoadCredential = [ "ha-token:${health.tokenFile}" ];
          ExecStart = "${pkgs.python3}/bin/python3 ${./reload-config.py} ${manifest}";
          TimeoutStartSec = "150s";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          UMask = "0077";
        };
      };
    }
  );
}
