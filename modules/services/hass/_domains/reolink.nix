# Reolink camera privacy policy
#
# Phoebe Cam's recording availability is controlled by privacy mode: privacy is
# on when Edmund or Monica is home, except when Goodnight mode is active.
# Otherwise privacy is off so recording is available.
{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled;
in
{
  services.home-assistant.config.automation = lib.mkAfter (ensureEnabled [
    {
      alias = "Phoebe Cam Privacy Policy";
      id = "phoebe_cam_privacy_policy";
      description = "Enable privacy mode when Edmund or Monica is home, except while Goodnight is active; disable it otherwise.";
      trigger = [
        {
          platform = "homeassistant";
          event = "start";
        }
        {
          platform = "state";
          entity_id = "person.edmund_miller";
        }
        {
          platform = "state";
          entity_id = "person.moni";
        }
        {
          platform = "state";
          entity_id = "input_boolean.goodnight";
        }
      ];
      action = [
        {
          choose = [
            {
              conditions = [
                {
                  condition = "and";
                  conditions = [
                    {
                      condition = "or";
                      conditions = [
                        {
                          condition = "state";
                          entity_id = "person.edmund_miller";
                          state = "home";
                        }
                        {
                          condition = "state";
                          entity_id = "person.moni";
                          state = "home";
                        }
                      ];
                    }
                    {
                      condition = "not";
                      conditions = [
                        {
                          condition = "state";
                          entity_id = "input_boolean.goodnight";
                          state = "on";
                        }
                      ];
                    }
                  ];
                }
              ];
              sequence = [
                {
                  action = "switch.turn_on";
                  target.entity_id = "switch.phoebe_cam_privacy_mode";
                }
              ];
            }
          ];
          default = [
            {
              action = "switch.turn_off";
              target.entity_id = "switch.phoebe_cam_privacy_mode";
            }
          ];
        }
      ];
    }
  ]);
}
