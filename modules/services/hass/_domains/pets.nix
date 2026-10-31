{ lib, ... }:
let
  inherit (import ../_lib.nix) ensureEnabled notificationPalette;
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

    input_text.phoebe_last_dental_treat = {
      name = "Phoebe Last Dental Treat";
      icon = "mdi:tooth";
      # An ISO timestamp restores across restarts and starts unset. Unlike an
      # unset input_datetime, it cannot mistake today's midnight for a treat.
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
      {
        alias = "Phoebe Dental Treat NFC - Record or Warn";
        id = "phoebe_dental_treat_nfc_record_or_warn";
        mode = "queued";
        trigger = {
          platform = "tag";
          tag_id = "32eb4a84-1dbb-477a-a775-6a344c3a7b25";
        };
        action = [
          {
            # A night ends at 6 a.m. local time, not at midnight.
            "if" = [
              {
                condition = "template";
                value_template = ''
                  {% set start = today_at('06:00') %}
                  {% if now() < start %}
                    {% set start = start - timedelta(days=1) %}
                  {% endif %}
                  {{ as_timestamp(states('input_text.phoebe_last_dental_treat'), 0)
                     >= as_timestamp(start) }}
                '';
              }
            ];
            "then" = [
              {
                # An unidentified scanner must never fall back to broadcast.
                condition = "template";
                value_template = "{{ device_attr(trigger.event.data.get('device_id'), 'name') is not none }}";
              }
              {
                # Mobile app services use the original name, not name_by_user.
                action = "{{ 'notify.mobile_app_' ~ (device_attr(trigger.event.data.device_id, 'name') | slugify) }}";
                data = {
                  title = "Phoebe already had her dental treat";
                  message = "Phoebe already got her dental treat tonight! Her small Yummy Comb (49 kcal) is already logged. Don't give her another one.";
                  data = notificationPalette.pets // {
                    notification_icon = "mdi:dog";
                  };
                };
              }
            ];
            "else" = [
              {
                action = "input_text.set_value";
                target.entity_id = "input_text.phoebe_last_dental_treat";
                data.value = "{{ now().isoformat() }}";
              }
              {
                action = "logbook.log";
                data = {
                  name = "Phoebe Dental Treat";
                  message = "Phoebe was given 1 small Yummy Combs dental treat, 49 kcal.";
                  entity_id = "input_text.phoebe_last_dental_treat";
                };
              }
            ];
          }
        ];
      }
    ]);
  };
}
