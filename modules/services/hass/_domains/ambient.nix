# Ambient domain — sun-based lighting, presence-based automations
# Migrated from Apple Home automations
{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled;
in
{
  services.home-assistant.config = {
    scene = lib.mkAfter [
      # West-facing windows — kill lights after sunrise, natural light is enough
      {
        name = "Mid-morning";
        icon = "mdi:weather-sunny";
        entities = {
          "light.essentials_a19_a60" = "off";
          "light.essentials_a19_a60_2" = "off";
          "light.essentials_a19_a60_3" = "off"; # Bathroom Nightstand
          "light.essentials_a19_a60_4" = "off"; # Window Nightstand
          "light.essentials_a19_a60_5" = "off"; # Wall Lamp
          "light.nanoleaf_multicolor_floor_lamp" = "off";
          "light.nanoleaf_multicolor_hd_ls" = "off";
          "light.smart_night_light_w" = "off";
          "cover.smartwings_window_covering" = "closed";
        };
      }
      # Lights on before sunset, blinds closed
      {
        name = "Sundown";
        icon = "mdi:weather-sunset";
        entities = {
          "light.essentials_a19_a60" = "on";
          "light.essentials_a19_a60_2" = "on";
          "light.essentials_a19_a60_3" = {
            state = "on";
            brightness = 64; # 25%
          }; # Bathroom Nightstand
          "light.essentials_a19_a60_4" = {
            state = "on";
            brightness = 64; # 25%
          }; # Window Nightstand
          "light.essentials_a19_a60_5" = "on"; # Wall Lamp
          "light.nanoleaf_multicolor_floor_lamp" = "on";
          "light.nanoleaf_multicolor_hd_ls" = "on";
          "light.smart_night_light_w" = "on";
          "cover.smartwings_window_covering" = "closed";
        };
      }
      # Welcome home
      {
        name = "Arrive Home";
        icon = "mdi:home-account";
        entities = {
          "input_boolean.goodnight" = "off";
          "switch.adaptive_lighting_sleep_mode_living_space" = "off";
          "light.essentials_a19_a60" = "on";
          "light.essentials_a19_a60_2" = "on";
          "light.essentials_a19_a60_3" = "on"; # Bathroom Nightstand
          "light.essentials_a19_a60_4" = "on"; # Window Nightstand
          "light.essentials_a19_a60_5" = "on"; # Wall Lamp
          "light.nanoleaf_multicolor_floor_lamp" = "on";
          "light.nanoleaf_multicolor_hd_ls" = "on";
          "light.smart_night_light_w" = "on";
        };
      }
      # Away — most things off, indicators stay on
      {
        name = "Leave Home";
        icon = "mdi:home-export-outline";
        entities = {
          "cover.smartwings_window_covering" = "closed";
          "light.essentials_a19_a60_3" = "off"; # Bathroom Nightstand
          "light.essentials_a19_a60_4" = "off"; # Window Nightstand
          "light.essentials_a19_a60_5" = "off"; # Wall Lamp
          "light.nanoleaf_multicolor_floor_lamp" = "off";
          "light.nanoleaf_multicolor_hd_ls" = "off";
          "light.smart_night_light_w" = "off";
          "switch.eve_energy_20ebu4101" = "off";
          # Indicators stay on
          "light.essentials_a19_a60" = "on";
          "light.essentials_a19_a60_2" = "on";
        };
      }
    ];

    script = lib.mkAfter {
      mid_morning = {
        alias = "Mid-morning";
        icon = "mdi:weather-sunny";
        sequence = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.mid_morning";
          }
        ];
      };
      sundown = {
        alias = "Sundown";
        icon = "mdi:weather-sunset";
        sequence = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.sundown";
          }
        ];
      };
      arrive_home = {
        alias = "Arrive Home";
        icon = "mdi:home-import-outline";
        sequence = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.arrive_home";
          }
        ];
      };
      leave_home = {
        alias = "Leave Home";
        icon = "mdi:home-export-outline";
        sequence = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.leave_home";
          }
        ];
      };
    };

    automation = lib.mkAfter (ensureEnabled [
      # --- Sun-based ---
      # Follows Good Morning — once natural light fills the west-facing
      # apartment, artificial lights are unnecessary.
      {
        alias = "Mid-morning";
        id = "mid_morning";
        description = "West-facing windows — kill lights and close blinds after sunrise";
        trigger = {
          platform = "sun";
          event = "sunrise";
          offset = "02:00:00";
        };
        condition = [
          {
            # Only act if we're past the sleep cycle — don't kill lights
            # if someone is still sleeping (goodnight still on)
            condition = "state";
            entity_id = "input_boolean.goodnight";
            state = "off";
          }
        ];
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.mid_morning";
          }
        ];
      }
      {
        alias = "Sundown";
        id = "sundown";
        description = "Turn on lights and close blinds before sunset";
        trigger = {
          platform = "sun";
          event = "sunset";
          offset = "-00:30:00";
        };
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.sundown";
          }
        ];
      }

      # --- Contact sensor (uncomment when balcony sensor is added to HA) ---
      # {
      #   alias = "Balcony door opened";
      #   id = "balcony_opens_couch_lamp";
      #   description = "Turn on couch lamp when balcony door opens";
      #   trigger = {
      #     platform = "state";
      #     entity_id = "binary_sensor.living_room_balcony_contact";
      #     to = "on";
      #   };
      #   action = [
      #     {
      #       action = "light.turn_on";
      #       target.entity_id = "light.nanoleaf_multicolor_floor_lamp";
      #     }
      #   ];
      # }

      # --- Occupancy ---
      {
        alias = "Entrance occupancy";
        id = "entrance_occupancy_night_light";
        description = "Night light on when motion detected, off after 5 min clear";
        trigger = {
          platform = "state";
          entity_id = "binary_sensor.smart_night_light_w_occupancy";
          to = "on";
        };
        condition = [
          {
            condition = "state";
            entity_id = "light.smart_night_light_w";
            state = "off";
          }
        ];
        action = [
          {
            action = "light.turn_on";
            target.entity_id = "light.smart_night_light_w";
          }
          {
            # Re-apply AL immediately so daytime color/brightness overrides
            # any stale sleep-mode orange left on the light.
            action = "adaptive_lighting.apply";
            data = {
              entity_id = "switch.adaptive_lighting_living_space";
              lights = [ "light.smart_night_light_w" ];
              adapt_color = true;
              adapt_brightness = true;
            };
          }
          {
            wait_for_trigger = [
              {
                platform = "state";
                entity_id = "binary_sensor.smart_night_light_w_occupancy";
                to = "off";
                "for".minutes = 5;
              }
            ];
            timeout.minutes = 30;
          }
          {
            action = "light.turn_off";
            target.entity_id = "light.smart_night_light_w";
          }
        ];
      }

      # --- Plant light schedule ---
      {
        alias = "Plant Glow Light on";
        id = "plant_glow_light_on";
        description = "Plant light on at 8 AM daily";
        trigger = {
          platform = "time";
          at = "08:00:00";
        };
        action = [
          {
            action = "switch.turn_on";
            target.entity_id = "switch.plant_glow_light";
          }
        ];
      }
      {
        alias = "Plant Glow Light off";
        id = "plant_glow_light_off";
        description = "Plant light off at 9 PM daily";
        trigger = {
          platform = "time";
          at = "21:00:00";
        };
        action = [
          {
            action = "switch.turn_off";
            target.entity_id = "switch.plant_glow_light";
          }
        ];
      }

      # --- Presence ---
      {
        alias = "Arrival flash wall lamp";
        id = "arrival_flash_wall_lamp";
        description = "Flash Wall Lamp blue for Edmund, yellow for Monica, then restore previous state";
        mode = "queued";
        max = 4;
        trigger = [
          {
            platform = "state";
            entity_id = "person.edmund_miller";
            to = "home";
          }
          {
            platform = "state";
            entity_id = "person.edmund_miller";
            to = "Parking Lot";
          }
          {
            platform = "state";
            entity_id = "person.moni";
            to = "home";
          }
          {
            platform = "state";
            entity_id = "person.moni";
            to = "Parking Lot";
          }
        ];
        action = [
          {
            action = "scene.create";
            data = {
              scene_id = "arrival_wall_lamp_previous";
              snapshot_entities = [ "light.essentials_a19_a60_5" ];
            };
          }
          {
            choose = [
              {
                conditions = [
                  {
                    condition = "template";
                    value_template = "{{ trigger.entity_id == 'person.edmund_miller' }}";
                  }
                ];
                sequence = [
                  {
                    repeat = {
                      count = 3;
                      sequence = [
                        {
                          action = "light.turn_on";
                          target.entity_id = "light.essentials_a19_a60_5";
                          data = {
                            brightness = 255;
                            hs_color = [
                              240
                              100
                            ];
                          };
                        }
                        { delay.milliseconds = 400; }
                        {
                          action = "light.turn_off";
                          target.entity_id = "light.essentials_a19_a60_5";
                        }
                        { delay.milliseconds = 400; }
                      ];
                    };
                  }
                ];
              }
            ];
            default = [
              {
                repeat = {
                  count = 3;
                  sequence = [
                    {
                      action = "light.turn_on";
                      target.entity_id = "light.essentials_a19_a60_5";
                      data = {
                        brightness = 255;
                        hs_color = [
                          60
                          100
                        ];
                      };
                    }
                    { delay.milliseconds = 400; }
                    {
                      action = "light.turn_off";
                      target.entity_id = "light.essentials_a19_a60_5";
                    }
                    { delay.milliseconds = 400; }
                  ];
                };
              }
            ];
          }
          {
            action = "scene.turn_on";
            target.entity_id = "scene.arrival_wall_lamp_previous";
          }
          {
            action = "adaptive_lighting.set_manual_control";
            data = {
              entity_id = "switch.adaptive_lighting_living_space";
              lights = [ "light.essentials_a19_a60_5" ];
              manual_control = false;
            };
          }
          {
            action = "adaptive_lighting.apply";
            data = {
              entity_id = "switch.adaptive_lighting_living_space";
              lights = [ "light.essentials_a19_a60_5" ];
              adapt_color = true;
              adapt_brightness = true;
              turn_on_lights = false;
            };
          }
        ];
      }
      {
        alias = "First person arrives home";
        id = "first_person_arrives";
        description = "Welcome home — lights on, house mode Home";
        trigger = [
          {
            platform = "state";
            entity_id = "person.edmund_miller";
            to = "home";
          }
          {
            platform = "state";
            entity_id = "person.moni";
            to = "home";
          }
        ];
        condition = [
          {
            # First to arrive — the triggering person is already "home",
            # so exactly 1 person home means nobody was here before
            condition = "template";
            value_template = "{{ states.person | selectattr('state', 'eq', 'home') | list | length == 1 }}";
          }
          {
            # Only run the welcome-light scene at night
            condition = "state";
            entity_id = "sun.sun";
            state = "below_horizon";
          }
        ];
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.arrive_home";
          }
        ];
      }
      {
        alias = "Last person leaves home";
        id = "last_person_leaves";
        description = "Everything off (except indicators), close blinds, away mode";
        trigger = [
          {
            platform = "state";
            entity_id = "person.edmund_miller";
            from = "home";
          }
          {
            platform = "state";
            entity_id = "person.moni";
            from = "home";
          }
        ];
        condition = [
          {
            # Only fire when no one is home
            condition = "template";
            value_template = "{{ states.person | selectattr('state', 'eq', 'home') | list | length == 0 }}";
          }
          {
            # Don't override vacation mode — it manages its own state
            condition = "state";
            entity_id = "input_boolean.vacation_mode";
            state = "off";
          }
        ];
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.leave_home";
          }
          {
            action = "script.tv_off_if_on";
          }
        ];
      }

      # --- Roomba ---
      {
        alias = "Roomba start — last person leaves";
        id = "roomba_start_last_person_leaves";
        description = "Start Rosie + Squirty when house empties; skip during goodnight mode";
        trigger = [
          {
            platform = "state";
            entity_id = "person.edmund_miller";
            from = "home";
          }
          {
            platform = "state";
            entity_id = "person.moni";
            from = "home";
          }
        ];
        condition = [
          {
            condition = "template";
            value_template = "{{ states.person | selectattr('state', 'eq', 'home') | list | length == 0 }}";
          }
          {
            condition = "state";
            entity_id = "input_boolean.vacation_mode";
            state = "off";
          }
          {
            # Sleep guard (xrqm.3) — don't vacuum when goodnight mode is active
            condition = "state";
            entity_id = "input_boolean.goodnight";
            state = "off";
          }
        ];
        action = [
          {
            action = "vacuum.start";
            target.entity_id = [
              "vacuum.squirty"
            ];
          }
        ];
      }
      {
        alias = "Roomba dock — first person arrives";
        id = "roomba_dock_first_person_arrives";
        description = "Return Rosie + Squirty to base when first person arrives home";
        trigger = [
          {
            platform = "state";
            entity_id = "person.edmund_miller";
            to = "home";
          }
          {
            platform = "state";
            entity_id = "person.moni";
            to = "home";
          }
        ];
        condition = [
          {
            # First to arrive — only 1 person now home
            condition = "template";
            value_template = "{{ states.person | selectattr('state', 'eq', 'home') | list | length == 1 }}";
          }
        ];
        action = [
          {
            action = "vacuum.return_to_base";
            target.entity_id = [
              "vacuum.rosie"
              "vacuum.squirty"
            ];
          }
        ];
      }
    ]);
  };
}
