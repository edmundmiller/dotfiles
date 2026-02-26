# Sweep unmanaged HA entities after deploy.
#
# Extracts declared automation IDs, scene entity_ids, and script entity_ids
# from the evaluated NixOS config at build time, writes a JSON manifest,
# then runs sweep-unmanaged.py post-deploy to remove orphans.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.services.hass;
  haConfig = config.services.home-assistant.config;

  # ── Extract declared entity identifiers from evaluated config ──────────

  # Automation IDs: each automation has an `id` field
  automationIds = lib.filter (id: id != null) (map (a: a.id or null) (haConfig.automation or [ ]));

  # Scene entity_ids: derived from scene name → scene.<snake_case_name>
  # HA converts "Good Morning" → scene.good_morning
  toEntityId =
    name:
    let
      lower = lib.toLower name;
      # Replace spaces and hyphens with underscores
      slug = builtins.replaceStrings [ " " "-" ] [ "_" "_" ] lower;
    in
    "scene.${slug}";

  sceneEntityIds = map (s: toEntityId (s.name or "")) (haConfig.scene or [ ]);

  # Script entity_ids: keys of the script attrset → script.<key>
  scriptEntityIds = map (k: "script.${k}") (builtins.attrNames (haConfig.script or { }));

  # Build-time JSON manifest
  declaredEntitiesJson = builtins.toJSON {
    automation_ids = automationIds;
    scene_entity_ids = sceneEntityIds;
    script_entity_ids = scriptEntityIds;
  };

  py = pkgs.python3.withPackages (ps: [ ps.websockets ]);

  declaredEntitiesFile = pkgs.writeText "ha-declared-entities.json" declaredEntitiesJson;

  sweepScript = pkgs.writeShellScript "hass-sweep" ''
    exec ${py}/bin/python3 ${./sweep-unmanaged.py} ${declaredEntitiesFile}
  '';

in
lib.mkIf cfg.enable {
  # Systemd service: sweep after HA starts (runs once per deploy)
  systemd.services.hass-sweep-unmanaged = {
    description = "Remove unmanaged HA automations/scenes/scripts";
    wantedBy = [ "multi-user.target" ];
    after = [
      "home-assistant.service"
      "hass-apply-devices.service"
    ];
    requires = [ "home-assistant.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Wait for HA to be ready (same pattern as apply-devices)
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 60); do ${pkgs.curl}/bin/curl -so /dev/null -w \"%%{http_code}\" http://127.0.0.1:8123/manifest.json 2>/dev/null | grep -q \"200\" && exit 0; sleep 2; done; echo \"HA not ready after 120s\"; exit 1'";
      ExecStart = "${sweepScript}";
    };
  };
}
