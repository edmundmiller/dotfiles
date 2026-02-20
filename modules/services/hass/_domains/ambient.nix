# Ambient domain — sun-based lighting, presence-based automations
# Migrated from Apple Home automations
{ lib, ... }:
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
          "light.essentials_a19_a60_3" = "off"; # Left Night Stand
          "light.essentials_a19_a60_4" = "off"; # Right Nightstand
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
          "light.essentials_a19_a60_3" = "on"; # Left Night Stand
          "light.essentials_a19_a60_4" = "on"; # Right Nightstand
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
          "input_select.house_mode" = "Home";
          "light.essentials_a19_a60" = "on";
          "light.essentials_a19_a60_2" = "on";
          "light.essentials_a19_a60_3" = "on"; # Left Night Stand
          "light.essentials_a19_a60_4" = "on"; # Right Nightstand
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
          "input_select.house_mode" = "Away";
          "cover.smartwings_window_covering" = "closed";
          "light.essentials_a19_a60_3" = "off"; # Left Night Stand
          "light.essentials_a19_a60_4" = "off"; # Right Nightstand
          "light.nanoleaf_multicolor_floor_lamp" = "off";
          "light.nanoleaf_multicolor_hd_ls" = "off";
          "light.smart_night_light_w" = "off";
          "media_player.tv" = "off";
          "switch.eve_energy_20ebu4101" = "off";
          # Indicators stay on
          "light.essentials_a19_a60" = "on";
          "light.essentials_a19_a60_2" = "on";
        };
      }
    ];

    automation = lib.mkAfter [
      # --- Sun-based ---
      {
        alias = "Mid-morning";
        id = "mid_morning";
        description = "West-facing windows — kill lights and close blinds after sunrise";
        trigger = {
          platform = "sun";
          event = "sunrise";
          offset = "02:00:00";
        };
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

      # --- Presence ---
      {
        alias = "First person arrives home";
        id = "first_person_arrives";
        description = "Welcome home — lights on, house mode Home";
        trigger = {
          platform = "state";
          entity_id = "person.edmund_miller";
          to = "home";
        };
        condition = [
          {
            condition = "state";
            entity_id = "input_select.house_mode";
            state = "Away";
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
        trigger = {
          platform = "state";
          entity_id = "person.edmund_miller";
          from = "home";
        };
        condition = [
          {
            # Only fire when no one is home
            condition = "template";
            value_template = "{{ states.person | selectattr('state', 'eq', 'home') | list | length == 0 }}";
          }
        ];
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.leave_home";
          }
        ];
      }
    ];
  };
}
