# Reolink camera privacy policy
#
# Phoebe Cam's recording availability is controlled by privacy mode: privacy is
# on when Edmund or Monica is home, except when the suite is actually in sleep mode.
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
      description = "Enable privacy mode when Edmund or Monica is home, except while the suite is in sleep mode; disable it otherwise.";
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
          entity_id = "select.master_suite_current_mode";
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
                          entity_id = "select.master_suite_current_mode";
                          state = "sleep";
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
