# Climate comfort policy for occupied cooling.
{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled;

  thermostats = [
    "climate.main_floor"
    "climate.master_suite"
  ];

  comfortTarget = "{{ states('input_number.occupied_cooling_target') | float(72) }}";
in
{
  services.home-assistant.config = {
    input_number.occupied_cooling_target = {
      name = "Occupied Cooling Target";
      icon = "mdi:snowflake-thermometer";
      min = 68;
      max = 76;
      step = 1;
      initial = 72;
      unit_of_measurement = "F";
    };

    script.cool_down = {
      alias = "Cool Down";
      icon = "mdi:snowflake";
      sequence = [
        {
          action = "climate.set_hvac_mode";
          target.entity_id = thermostats;
          data.hvac_mode = "cool";
        }
        {
          action = "climate.set_temperature";
          target.entity_id = thermostats;
          data.temperature = comfortTarget;
        }
      ];
    };

    automation = lib.mkAfter (ensureEnabled [
      {
        alias = "Occupied cooling comfort";
        id = "occupied_cooling_comfort";
        description = "When someone is home and the apartment is warm, keep both Ecobees at the occupied cooling target.";
        trigger = [
          {
            platform = "homeassistant";
            event = "start";
          }
          {
            platform = "state";
            entity_id = [
              "person.edmund_miller"
              "person.moni"
            ];
            to = "home";
          }
          {
            platform = "state";
            entity_id = "input_boolean.goodnight";
            to = "off";
          }
          {
            platform = "numeric_state";
            entity_id = "sensor.main_floor_current_temperature";
            above = 74.5;
            "for".minutes = 10;
          }
          {
            platform = "numeric_state";
            entity_id = "sensor.master_suite_current_temperature";
            above = 74.5;
            "for".minutes = 10;
          }
        ];
        condition = [
          {
            condition = "state";
            entity_id = "input_boolean.vacation_mode";
            state = "off";
          }
          {
            condition = "template";
            value_template = "{{ is_state('person.edmund_miller', 'home') or is_state('person.moni', 'home') }}";
          }
          {
            condition = "template";
            value_template = ''
              {{ states('sensor.main_floor_current_temperature') | float(0) > 74.5
                 or states('sensor.master_suite_current_temperature') | float(0) > 74.5 }}
            '';
          }
        ];
        action = [
          {
            action = "script.cool_down";
          }
        ];
      }
    ]);
  };
}
