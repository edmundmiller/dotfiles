{ nixosConfig, pkgs }:
let
  hass = nixosConfig.config.services.home-assistant.package;
  haConfig = nixosConfig.config.services.home-assistant.config;
  python = hass.python3Packages.python.withPackages (_: hass.propagatedBuildInputs);
  morningConfig = pkgs.writeText "good-morning-config.json" (
    builtins.toJSON {
      inherit (haConfig) scene input_boolean;
      script = {
        inherit (haConfig.script)
          good_morning
          get_ready_for_bed
          goodnight
          sleep
          ;
      };
    }
  );
  automationConfig =
    id:
    pkgs.writeText "${id}.json" (
      builtins.toJSON (
        builtins.head (builtins.filter (automation: automation.id == id) haConfig.automation)
      )
    );
  petsConfig = pkgs.writeText "pets-config.json" (
    builtins.toJSON {
      input_datetime = { inherit (haConfig.input_datetime) phoebe_last_fed; };
      input_text = { inherit (haConfig.input_text) phoebe_last_dental_treat; };
      automation = builtins.filter (
        automation:
        builtins.elem automation.id [
          "phoebe_kibble_nfc_record_feeding"
          "phoebe_dental_treat_nfc_record_or_warn"
        ]
      ) haConfig.automation;
    }
  );
  monicaConfig = pkgs.writeText "monica-routine-config.json" (
    builtins.toJSON {
      input_text = {
        inherit (haConfig.input_text) monica_routine_started_at monica_in_bed_at;
      };
      input_boolean = { inherit (haConfig.input_boolean) goodnight; };
      timer = { inherit (haConfig.timer) mirror_bedtime; };
      template = builtins.filter (
        template:
        builtins.any (sensor: (sensor.unique_id or "") == "monica_bedtime_routine_duration") (
          template.sensor or [ ]
        )
      ) haConfig.template;
      automation = builtins.filter (
        automation:
        builtins.elem automation.id [
          "monica_mirror_nfc_get_ready_for_bed"
          "monica_nightstand_nfc_goodnight"
        ]
      ) haConfig.automation;
    }
  );
in
pkgs.runCommand "ha-behavior-tests" { nativeBuildInputs = [ python ]; } ''
  export HOME=$TMPDIR
  export PYTHONDONTWRITEBYTECODE=1
  export PYTHONPATH=${hass}/${python.sitePackages}
  python3 ${./test_good_morning.py} ${morningConfig} -v
  python3 ${./test_bedtime_audio.py} ${automationConfig "white_noise_with_bedtime_audiobook"} -v
  python3 ${./test_entrance_night_light.py} ${automationConfig "entrance_night_light_off_when_clear"} -v
  python3 ${./test_pets.py} ${petsConfig} -v
  python3 ${./test_monica_routine.py} ${monicaConfig} -v
  touch "$out"
''
