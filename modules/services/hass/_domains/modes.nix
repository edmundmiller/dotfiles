# House modes domain — mode switching, routines, DND
{ lib, ... }:
let
  setMode = mode: {
    action = "input_select.select_option";
    target.entity_id = "input_select.house_mode";
    data.option = mode;
  };

  tvOff = {
    action = "media_player.turn_off";
    target.entity_id = "media_player.tv";
  };
in
{
  services.home-assistant.config = {
    # --- Input helpers ---
    input_boolean = {
      guest_mode = {
        name = "Guest Mode";
        icon = "mdi:account-group";
      };
      goodnight = {
        name = "Goodnight";
        icon = "mdi:weather-night";
      };
      do_not_disturb = {
        name = "Do Not Disturb";
        icon = "mdi:minus-circle";
      };
      # Wake detection — used by sleep/ automations
      edmund_awake = {
        name = "Edmund Awake";
        icon = "mdi:sleep-off";
      };
      monica_awake = {
        name = "Monica Awake";
        icon = "mdi:sleep-off";
      };
    };

    input_select.house_mode = {
      name = "House Mode";
      options = [
        "Home"
        "Away"
        "Night"
        "Vacation"
      ];
      initial = "Home";
      icon = "mdi:home";
    };

    # --- Scenes ---
    scene = [
      {
        name = "Good Morning";
        icon = "mdi:weather-sunny";
        entities = {
          "input_boolean.goodnight" = "off";
          "input_boolean.edmund_awake" = "off"; # reset for next night
          "input_boolean.monica_awake" = "off";
          "input_select.house_mode" = "Home";
          "cover.smartwings_window_covering" = {
            state = "open";
            position = 20; # crack — natural light without full exposure
          };
          "switch.eve_energy_20ebu4101" = "off"; # whitenoise machine
        };
      }
    ];

    # --- Scripts ---
    script.everything_off = {
      alias = "Everything Off";
      icon = "mdi:power";
      description = "Nuclear option — all lights, blinds, TV, mode Night";
      sequence = [
        {
          action = "light.turn_off";
          target.entity_id = [
            "light.essentials_a19_a60"
            "light.essentials_a19_a60_2"
            "light.essentials_a19_a60_3" # Bathroom Nightstand
            "light.essentials_a19_a60_4" # Window Nightstand
            "light.nanoleaf_multicolor_floor_lamp"
            "light.nanoleaf_multicolor_hd_ls"
            "light.smart_night_light_w"
          ];
        }
        {
          action = "cover.close_cover";
          target.entity_id = "cover.smartwings_window_covering";
        }
        tvOff
        {
          action = "input_boolean.turn_on";
          target.entity_id = "input_boolean.goodnight";
        }
        (setMode "Night")
      ];
    };

    # --- Automations ---
    automation = lib.mkAfter [
      {
        alias = "Good Morning";
        id = "good_morning_reset";
        description = "Reset night mode when goodnight toggle turns off — delegates to scene for full morning reset (blinds, whitenoise, mode, wake booleans)";
        trigger = {
          platform = "state";
          entity_id = "input_boolean.goodnight";
          to = "off";
        };
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.good_morning";
          }
        ];
      }

      # Away mode — safety net for manual mode changes
      # (presence-based Leave Home scene handles the automatic case)
      {
        alias = "Away mode";
        id = "away_mode_media_off";
        trigger = {
          platform = "state";
          entity_id = "input_select.house_mode";
          to = "Away";
        };
        action = [ tvOff ];
      }

      # DND
      {
        alias = "Do Not Disturb";
        id = "dnd_on";
        trigger = {
          platform = "state";
          entity_id = "input_boolean.do_not_disturb";
          to = "on";
        };
        action = [
          {
            action = "notify.persistent_notification";
            data = {
              message = "Do Not Disturb is active";
              title = "🔕 DND";
            };
          }
        ];
      }
    ];
  };
}
