# Reolink camera privacy policy
#
# Phoebe Cam's recording availability is controlled by privacy mode: privacy is
# off when the apartment is empty or the suite is actually in sleep mode, and
# on when someone is home and the suite is not sleeping.
{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled;
in
{
  services.home-assistant.config.automation = lib.mkAfter (ensureEnabled [
    {
      alias = "Phoebe Cam Privacy Policy";
      id = "phoebe_cam_privacy_policy";
      description = "Disable privacy mode when everyone is away or the suite is in sleep mode; enable it otherwise.";
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
                  condition = "or";
                  conditions = [
                    {
                      condition = "state";
                      entity_id = "select.master_suite_current_mode";
                      state = "sleep";
                    }
                    {
                      condition = "and";
                      conditions = [
                        {
                          condition = "state";
                          entity_id = "person.edmund_miller";
                          state = "not_home";
                        }
                        {
                          condition = "state";
                          entity_id = "person.moni";
                          state = "not_home";
                        }
                      ];
                    }
                  ];
                }
              ];
              sequence = [
                {
                  action = "switch.turn_off";
                  target.entity_id = "switch.phoebe_cam_privacy_mode";
                }
              ];
            }
          ];
          default = [
            {
              action = "switch.turn_on";
              target.entity_id = "switch.phoebe_cam_privacy_mode";
            }
          ];
        }
      ];
    }
  ]);
}
