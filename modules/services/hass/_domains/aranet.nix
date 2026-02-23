# Aranet4 CO2 sensor — air quality monitoring + ventilation alerts
# Integration: built-in HA Bluetooth/Aranet
# Sensors: CO2 (ppm), temperature, humidity, pressure, battery
#
# Entity IDs: update ARANET_PREFIX to match your device MAC-derived suffix
# (find in HA → Developer Tools → States, filter by "aranet4")
{ lib, ... }:
let
  # Update this to match your Aranet4 entity prefix
  # e.g. sensor.aranet4_ab12cd_carbon_dioxide → prefix is "aranet4_ab12cd"
  prefix = "aranet4_XXXXXX";
  co2 = "sensor.${prefix}_carbon_dioxide";

  # CO2 thresholds (ppm)
  thresholdWarn = 1000; # Elevated — consider ventilating
  thresholdBad = 1500; # Poor — ventilate now
in
{
  services.home-assistant.config = {
    automation = lib.mkAfter [
      # --- CO2 alert: elevated ---
      {
        alias = "CO2 elevated";
        id = "co2_elevated";
        description = "Notify when CO2 crosses ${toString thresholdWarn} ppm — open a window";
        trigger = {
          platform = "numeric_state";
          entity_id = co2;
          above = thresholdWarn;
          for.minutes = 5; # Debounce: sustained for 5 min before alerting
        };
        action = [
          {
            action = "notify.mobile_app_edmunds_iphone";
            data = {
              title = "🌬️ Air Quality";
              message = "CO2 is high ({{ states('${co2}') }} ppm) — open a window";
              data.push.interruption-level = "time-sensitive";
            };
          }
        ];
      }

      # --- CO2 alert: poor ---
      {
        alias = "CO2 poor";
        id = "co2_poor";
        description = "Urgent alert when CO2 exceeds ${toString thresholdBad} ppm";
        trigger = {
          platform = "numeric_state";
          entity_id = co2;
          above = thresholdBad;
          for.minutes = 3;
        };
        action = [
          {
            action = "notify.mobile_app_edmunds_iphone";
            data = {
              title = "⚠️ Poor Air Quality";
              message = "CO2 is very high ({{ states('${co2}') }} ppm) — ventilate now";
              data.push.interruption-level = "active";
            };
          }
        ];
      }

      # --- CO2 cleared ---
      {
        alias = "CO2 cleared";
        id = "co2_cleared";
        description = "Notify when CO2 drops back below ${toString thresholdWarn} ppm";
        trigger = {
          platform = "numeric_state";
          entity_id = co2;
          below = thresholdWarn;
          for.minutes = 5;
        };
        condition = [
          # Only send if we previously sent a high alert (CO2 was elevated)
          {
            condition = "template";
            value_template = "{{ trigger.from_state.state | float(0) > ${toString thresholdWarn} }}";
          }
        ];
        action = [
          {
            action = "notify.mobile_app_edmunds_iphone";
            data = {
              title = "✅ Air Quality OK";
              message = "CO2 back to normal ({{ states('${co2}') }} ppm)";
            };
          }
        ];
      }
    ];
  };
}
