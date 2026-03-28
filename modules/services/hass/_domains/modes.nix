# House modes domain — DND, guest mode, utility scripts
#
# Sleep/wake lifecycle (goodnight, awake booleans, Good Morning) → sleep/
# Vacation mode → vacation.nix
{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled;
in
{
  services.home-assistant.config = {
    # --- Input helpers ---
    input_boolean = {
      guest_mode = {
        name = "Guest Mode";
        icon = "mdi:account-group";
      };
      do_not_disturb = {
        name = "Do Not Disturb";
        icon = "mdi:minus-circle";
      };
    };

    # --- Scripts ---
    # Power switch — kills lights, TV, blinds. Does NOT activate bedtime
    # state (goodnight, sleep mode). Use Winding Down for that.
    script.everything_off = {
      alias = "Everything Off";
      icon = "mdi:power";
      description = "Kill all lights, TV, close blinds. No bedtime state — safe to call any time of day.";
      sequence = [
        {
          action = "light.turn_off";
          target.entity_id = [
            "light.essentials_a19_a60" # Trashcan
            "light.essentials_a19_a60_2" # Dishwasher
            "light.essentials_a19_a60_3" # Bathroom Nightstand
            "light.essentials_a19_a60_4" # Window Nightstand
            "light.nanoleaf_multicolor_floor_lamp" # Couch Lamp
            "light.nanoleaf_multicolor_hd_ls" # Edmund Desk
            "light.smart_night_light_w" # Night light
          ];
        }
        {
          action = "media_player.turn_off";
          target.entity_id = "media_player.tv";
        }
        {
          action = "cover.close_cover";
          target.entity_id = "cover.smartwings_window_covering";
        }
      ];
    };

    # --- Automations ---
    automation = lib.mkAfter (ensureEnabled [
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
    ]);
  };
}
