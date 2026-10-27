{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled;
in
{
  services.home-assistant.config = {
    input_datetime.phoebe_last_fed = {
      name = "Phoebe Last Fed";
      icon = "mdi:dog";
      has_date = true;
      has_time = true;
      # No initial value: restore the last feeding time after a restart.
    };

    automation = lib.mkAfter (ensureEnabled [
      {
        alias = "Phoebe Kibble NFC - Record Feeding";
        id = "phoebe_kibble_nfc_record_feeding";
        mode = "single";
        trigger = {
          platform = "tag";
          tag_id = "729d23f5-3368-487e-bff0-3cf6a22cba29";
        };
        action = [
          {
            action = "input_datetime.set_datetime";
            target.entity_id = "input_datetime.phoebe_last_fed";
            data.timestamp = "{{ now().timestamp() }}";
          }
          {
            action = "logbook.log";
            data = {
              name = "Phoebe Feeding";
              message = "Phoebe was fed 1/4 cup of Hill's Science Diet Adult Sensitive Stomach & Skin kibble, 97.75 kcal.";
              entity_id = "input_datetime.phoebe_last_fed";
            };
          }
        ];
      }
    ]);
  };
}
