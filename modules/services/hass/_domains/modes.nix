# House modes domain — DND, guest mode, utility scripts
#
# Sleep/wake lifecycle (goodnight, awake booleans, Good Morning) → sleep/
# Vacation mode → vacation.nix
{ lib, ... }:
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
    script.everything_off = {
      alias = "Everything Off";
      icon = "mdi:power";
      description = "Nuclear option — delegates to Winding Down scene (goodnight, AL sleep mode, blinds, TV, lights), then kills night light too";
      sequence = [
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
