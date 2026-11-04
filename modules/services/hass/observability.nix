{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
lib.optionalAttrs (!isDarwin) (
  lib.mkIf config.modules.services.hass.enable {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "hass-health" ''
        export HASS_EXPECTED_VERSION="''${HASS_EXPECTED_VERSION-${config.services.home-assistant.package.version}}"
        export HASS_CRITICAL_ENTITIES="''${HASS_CRITICAL_ENTITIES-climate.main_floor climate.master_suite script.goodnight script.good_morning script.get_ready_for_bed}"
        exec ${pkgs.python3.withPackages (ps: [ ps.websockets ])}/bin/python3 ${./hass-health.py} "$@"
      '')
    ];

    services.home-assistant.config.script =
      lib.genAttrs
        [
          "get_ready_for_bed"
          "goodnight"
          "good_morning"
          "apply_climate_policy"
          "apply_ecobee_profile"
          "apply_ecobee_target"
        ]
        (_: {
          trace.stored_traces = 20;
        });
  }
)
