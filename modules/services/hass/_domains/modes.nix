# House modes domain — mode switching, goodnight/morning routines, DND
{ lib, ... }:
let
  # --- Helper functions ---
  setMode = mode: {
    action = "input_select.select_option";
    target.entity_id = "input_select.house_mode";
    data.option = mode;
  };

  tvOff = {
    action = "media_player.turn_off";
    target.entity_id = "media_player.tv";
  };

  tvOn = {
    action = "media_player.turn_on";
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
    };

    input_select.house_mode = {
      name = "House Mode";
      options = [
        "Home"
        "Away"
        "Night"
        "Movie"
      ];
      initial = "Home";
      icon = "mdi:home";
    };

    input_datetime = {
      morning_time = {
        name = "Morning Time";
        icon = "mdi:weather-sunset-up";
        has_date = false;
        has_time = true;
      };
      bedtime = {
        name = "Bedtime";
        icon = "mdi:weather-night";
        has_date = false;
        has_time = true;
      };
    };

    # --- Scenes ---
    scene = [
      {
        name = "Movie";
        icon = "mdi:movie-open";
        entities = {
          "input_select.house_mode" = "Movie";
          "media_player.tv" = "on";
        };
      }
      {
        name = "Goodnight";
        icon = "mdi:weather-night";
        entities = {
          "input_boolean.goodnight" = "on";
          "input_select.house_mode" = "Night";
          "media_player.tv" = "off";
        };
      }
      {
        name = "Good Morning";
        icon = "mdi:weather-sunny";
        entities = {
          "input_boolean.goodnight" = "off";
          "input_select.house_mode" = "Home";
        };
      }
    ];

    # --- Scripts ---
    script.everything_off = {
      alias = "Everything Off";
      icon = "mdi:power";
      sequence = [
        {
          action = "light.turn_off";
          target.entity_id = [
            "light.essentials_a19_a60"
            "light.essentials_a19_a60_2"
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
      # Goodnight routine
      {
        alias = "Goodnight - everything off";
        id = "goodnight_everything_off";
        trigger = {
          platform = "state";
          entity_id = "input_boolean.goodnight";
          to = "on";
        };
        action = [
          tvOff
          (setMode "Night")
        ];
      }
      {
        alias = "Good Morning - reset night mode";
        id = "good_morning_reset";
        trigger = {
          platform = "state";
          entity_id = "input_boolean.goodnight";
          to = "off";
        };
        action = [ (setMode "Home") ];
      }

      # Movie mode
      {
        alias = "Movie mode on";
        id = "movie_mode_on";
        trigger = {
          platform = "state";
          entity_id = "input_select.house_mode";
          to = "Movie";
        };
        action = [ tvOn ];
      }
      {
        alias = "Movie mode off";
        id = "movie_mode_off";
        trigger = {
          platform = "state";
          entity_id = "input_select.house_mode";
          from = "Movie";
        };
        action = [ ];
        # Add light restore here when you have smart lights
      }

      # Away mode
      {
        alias = "Away mode - turn off media";
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
        alias = "DND on - suppress notifications";
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
