# House modes domain — mode switching, routines, DND
{ lib, ... }:
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
      # No initial — persists across HA restarts (critical: initial="Home"
      # was resetting Night mode on restart, breaking wake detection)
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
          "switch.adaptive_lighting_sleep_mode_living_space" = "off";
        };
      }
    ];

    # --- Scripts ---
    script.everything_off = {
      alias = "Everything Off";
      icon = "mdi:power";
      description = "Nuclear option — delegates to Winding Down scene (goodnight, mode Night, AL sleep mode, blinds, TV, lights), then kills night light too";
      sequence = [
        # Winding Down: goodnight=on, mode=Night, AL sleep mode on, blinds closed,
        # TV off, main lights off, wake booleans reset. Night light stays on there —
        # nuclear option wants it off too.
        {
          action = "scene.turn_on";
          target.entity_id = "scene.winding_down";
        }
        {
          action = "light.turn_off";
          target.entity_id = "light.smart_night_light_w";
        }
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

      # Away mode — safety net for voice/dashboard mode changes
      # (presence-based Last Person Leaves automation also calls Leave Home)
      {
        alias = "Away mode";
        id = "away_mode_media_off";
        trigger = {
          platform = "state";
          entity_id = "input_select.house_mode";
          to = "Away";
        };
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.leave_home";
          }
        ];
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
