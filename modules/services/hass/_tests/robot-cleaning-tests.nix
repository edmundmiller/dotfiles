{ nixosConfig, pkgs }:
let
  hass = nixosConfig.config.services.home-assistant.package;
  haConfig = nixosConfig.config.services.home-assistant.config;
  python = hass.python3Packages.python.withPackages (_: hass.propagatedBuildInputs);
  cleaningConfig = pkgs.writeText "robot-cleaning-config.json" (
    builtins.toJSON (
      builtins.mapAttrs (_: pkgs.lib.filterAttrs (name: _: pkgs.lib.hasPrefix "robot_cleaning_" name)) {
        inherit (haConfig)
          script
          input_boolean
          input_datetime
          input_text
          ;
      }
      // {
        automation = builtins.filter (
          automation: pkgs.lib.hasPrefix "robot_cleaning_" (automation.id or "")
        ) haConfig.automation;
      }
    )
  );
in
pkgs.runCommand "ha-robot-cleaning-tests" { nativeBuildInputs = [ python ]; } ''
  export HOME=$TMPDIR
  export PYTHONDONTWRITEBYTECODE=1
  export PYTHONPATH=${hass}/${python.sitePackages}
  python3 ${./test_robot_cleaning.py} ${cleaningConfig} -v
  touch "$out"
''
