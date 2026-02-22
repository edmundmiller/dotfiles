# Sleep domain — bedtime progression, bed presence, wake routines
#
# Three-stage bedtime flow:
#   1. Winding Down  — get ready for bed (night light stays on for navigation)
#   2. In Bed        — settled in, audiobook time (whitenoise on, lights off)
#   3. Sleep         — done with audiobook, out cold (whitenoise stays)
#
# Triggers:
#   Winding Down  ← 10:00 PM daily
#   In Bed        ← bed presence (Monica, 2 min)
#   Sleep         ← manual or future: audiobook stops / sleep focus activates
#
# Apple integration (iPhone ↔ 8Sleep):
#   iPhone alarm sensor  → set_one_off_alarm on 8Sleep (keeps them in sync)
#   Sleep Focus off 6–9am → dismiss 8Sleep alarm + side_off (manual wake = skip alarm)
#
# Entity name notes (verify in HA dev tools > States if IDs change):
#   8Sleep service target: sensor.edmund_s_eight_sleep_side_sleep_stage
#   8Sleep next alarm switch: switch.edmund_s_eight_sleep_next_alarm
#   iPhone next alarm: sensor.edmunds_iphone_next_alarm (datetime)
#   iPhone focus: binary_sensor.edmunds_iphone_focus (on = any focus active)
#
# Wake detection state machine:
#   input_boolean.edmund_awake / monica_awake track who's up
#   Set by: bed presence off (2 min) OR focus off, during Night mode
#   Reset by: Goodnight scene (modes.nix) and Good Morning scene
#   Good Morning fires when both are on
{ lib, ... }:
{
  services.home-assistant.config = {
    # --- Wake detection helpers ---
    input_boolean = {
      edmund_awake = {
        name = "Edmund Awake";
        icon = "mdi:sleep-off";
      };
      monica_awake = {
        name = "Monica Awake";
        icon = "mdi:sleep-off";
      };
    };
    scene = lib.mkAfter [
      # Stage 1: Get ready for bed
      {
        name = "Winding Down";
        icon = "mdi:weather-night";
        entities = {
          "input_boolean.goodnight" = "on";
          "input_boolean.edmund_awake" = "off"; # reset wake tracking
          "input_boolean.monica_awake" = "off";
          "input_select.house_mode" = "Night";
          "cover.smartwings_window_covering" = "closed";
          "media_player.tv" = "off";

          # Main lights off
          "light.essentials_a19_a60" = "off"; # Trashcan
          "light.essentials_a19_a60_2" = "off"; # Dishwasher
          "light.essentials_a19_a60_3" = "off"; # Bathroom Nightstand
          "light.essentials_a19_a60_4" = "off"; # Window Nightstand
          "light.nanoleaf_multicolor_floor_lamp" = "off"; # Couch Lamp
          "light.nanoleaf_multicolor_hd_ls" = "off"; # Edmund Desk

          # Night light stays on — navigate to bed
          "light.smart_night_light_w" = "on";
        };
      }
      # Stage 2: In bed, audiobook time
      {
        name = "In Bed";
        icon = "mdi:bed";
        entities = {
          "switch.eve_energy_20ebu4101" = "on"; # Whitenoise
          "light.smart_night_light_w" = "off"; # No longer needed
        };
      }
      # Stage 3: Audiobook done, sleeping
      {
        name = "Sleep";
        icon = "mdi:sleep";
        entities = {
          # Confirm sealed state — whitenoise stays, everything else off
          "input_boolean.goodnight" = "on";
          "input_select.house_mode" = "Night";
          "switch.eve_energy_20ebu4101" = "on"; # Whitenoise stays
          "cover.smartwings_window_covering" = "closed";
          "media_player.tv" = "off";
          "light.essentials_a19_a60" = "off";
          "light.essentials_a19_a60_2" = "off";
          "light.essentials_a19_a60_3" = "off"; # Bathroom Nightstand
          "light.essentials_a19_a60_4" = "off"; # Window Nightstand
          "light.nanoleaf_multicolor_floor_lamp" = "off";
          "light.nanoleaf_multicolor_hd_ls" = "off";
          "light.smart_night_light_w" = "off";
        };
      }
    ];

    script = lib.mkAfter {
      # Monica voice-activates this to nudge Edmund to come to bed
      bedtime_nudge = {
        alias = "Bedtime Nudge";
        icon = "mdi:bed-clock";
        sequence = [
          {
            action = "notify.mobile_app_edmunds_iphone";
            data = {
              title = "🛏️ Bedtime";
              message = "Monica's heading to bed — time to wrap up!";
            };
          }
        ];
      };
    };

    automation = lib.mkAfter [
      # Stage 1: 10 PM → Winding Down
      {
        alias = "Winding Down";
        id = "winding_down";
        description = "10 PM — lights off (night light stays), blinds closed, TV off";
        trigger = {
          platform = "time";
          at = "22:00:00";
        };
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.winding_down";
          }
        ];
      }

      # Stage 2: Bed presence → In Bed
      {
        alias = "In Bed";
        id = "bed_presence_in_bed";
        description = "Monica in bed 2 min → whitenoise on, night light off";
        trigger = {
          platform = "state";
          entity_id = "binary_sensor.monica_s_eight_sleep_side_bed_presence";
          to = "on";
          "for".minutes = 2;
        };
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.in_bed";
          }
        ];
      }

      # Bedtime nudge webhook (Monica: "Hey Siri, I'm getting into bed")
      {
        alias = "Bedtime nudge";
        id = "bedtime_nudge_webhook";
        trigger = {
          platform = "webhook";
          webhook_id = "bedtime-nudge-monica";
          allowed_methods = [ "POST" ];
          local_only = true;
        };
        action = [
          {
            action = "script.bedtime_nudge";
          }
        ];
      }

      # ── Apple ↔ 8Sleep integration ─────────────────────────────────────────

      # Sync Edmund's iPhone next alarm → 8Sleep one-off alarm
      # iPhone sensor is a datetime; extract local time for set_one_off_alarm.
      # Conditions filter out unavailable state and non-morning alarms (≥11am
      # = not a wake alarm, skip it).
      {
        alias = "Sync iPhone Alarm to 8Sleep";
        id = "sync_iphone_alarm_8sleep";
        description = "iPhone next alarm changes → set matching one-off alarm on 8Sleep";
        trigger = {
          platform = "state";
          entity_id = "sensor.edmunds_iphone_next_alarm";
        };
        condition = [
          {
            condition = "template";
            value_template = "{{ states('sensor.edmunds_iphone_next_alarm') not in ['unknown', 'unavailable', 'none'] }}";
          }
          {
            condition = "template";
            # Ignore alarms set for 11am or later — those aren't sleep alarms
            value_template = "{{ (states('sensor.edmunds_iphone_next_alarm') | as_datetime | as_local).hour < 11 }}";
          }
        ];
        action = [
          {
            # Verify entity in HA dev-tools → States: filter eight_sleep / sensor
            action = "eight_sleep.set_one_off_alarm";
            target.entity_id = "sensor.edmund_s_eight_sleep_side_sleep_stage";
            data = {
              time = "{{ (states('sensor.edmunds_iphone_next_alarm') | as_datetime | as_local).strftime('%H:%M:%S') }}";
              enabled = true;
              vibration_enabled = true;
              vibration_power_level = "50";
              thermal_enabled = false; # thermal wake handled by existing 8Sleep routine
            };
          }
        ];
      }

      # Sleep Focus off 6–9am → cancel + dismiss 8Sleep alarm, turn off Edmund's side
      # Covers two cases: alarm hasn't fired yet (switch off) and actively ringing (dismiss).
      {
        alias = "Sleep Focus Off - Stop Edmund 8Sleep";
        id = "sleep_focus_off_stop_edmund";
        description = "Edmund turns off Sleep Focus 6–9am → cancel alarm, turn off bed";
        trigger = {
          platform = "state";
          entity_id = "binary_sensor.edmunds_iphone_focus";
          to = "off";
        };
        condition = [
          {
            condition = "time";
            after = "06:00:00";
            before = "09:00:00";
          }
          {
            condition = "state";
            entity_id = "input_select.house_mode";
            state = "Night";
          }
        ];
        action = [
          # Cancel if not yet ringing
          {
            action = "switch.turn_off";
            target.entity_id = "switch.edmund_s_eight_sleep_next_alarm";
          }
          # Dismiss if actively ringing
          {
            action = "eight_sleep.alarm_dismiss";
            target.entity_id = "sensor.edmund_s_eight_sleep_side_sleep_stage";
          }
          # Stop heating/cooling
          {
            action = "eight_sleep.side_off";
            target.entity_id = "sensor.edmund_s_eight_sleep_side_sleep_stage";
          }
        ];
      }

      # Sleep Focus off 6–9am → cancel + dismiss 8Sleep alarm, turn off Monica's side
      {
        alias = "Sleep Focus Off - Stop Monica 8Sleep";
        id = "sleep_focus_off_stop_monica";
        description = "Monica turns off Sleep Focus 6–9am → cancel alarm, turn off bed";
        trigger = {
          platform = "state";
          entity_id = "binary_sensor.monicas_iphone_focus";
          to = "off";
        };
        condition = [
          {
            condition = "time";
            after = "06:00:00";
            before = "09:00:00";
          }
          {
            condition = "state";
            entity_id = "input_select.house_mode";
            state = "Night";
          }
        ];
        action = [
          {
            action = "switch.turn_off";
            target.entity_id = "switch.monica_s_eight_sleep_next_alarm";
          }
          {
            action = "eight_sleep.alarm_dismiss";
            target.entity_id = "sensor.monica_s_eight_sleep_side_sleep_stage";
          }
          {
            action = "eight_sleep.side_off";
            target.entity_id = "sensor.monica_s_eight_sleep_side_sleep_stage";
          }
        ];
      }

      # ── Wake detection state machine ─────────────────────────────────────
      #
      # Each person gets an "awake" boolean set by bed presence OR focus off.
      # Good Morning fires when BOTH are on — handles different wake times.
      # Booleans reset by Winding Down / Good Morning scenes.

      # Edmund shows awake signal → mark awake
      {
        alias = "Edmund is awake";
        id = "edmund_awake_detection";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.edmund_s_eight_sleep_side_bed_presence";
            to = "off";
            "for".minutes = 2;
          }
          {
            platform = "state";
            entity_id = "binary_sensor.edmunds_iphone_focus";
            to = "off";
          }
        ];
        condition = [
          {
            condition = "state";
            entity_id = "input_select.house_mode";
            state = "Night";
          }
          {
            condition = "state";
            entity_id = "input_boolean.edmund_awake";
            state = "off";
          }
        ];
        action = [
          {
            action = "input_boolean.turn_on";
            target.entity_id = "input_boolean.edmund_awake";
          }
        ];
      }

      # Monica shows awake signal → mark awake
      {
        alias = "Monica is awake";
        id = "monica_awake_detection";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.monica_s_eight_sleep_side_bed_presence";
            to = "off";
            "for".minutes = 2;
          }
          {
            platform = "state";
            entity_id = "binary_sensor.monicas_iphone_focus";
            to = "off";
          }
        ];
        condition = [
          {
            condition = "state";
            entity_id = "input_select.house_mode";
            state = "Night";
          }
          {
            condition = "state";
            entity_id = "input_boolean.monica_awake";
            state = "off";
          }
        ];
        action = [
          {
            action = "input_boolean.turn_on";
            target.entity_id = "input_boolean.monica_awake";
          }
        ];
      }

      # Both awake → Good Morning
      {
        alias = "Good Morning";
        id = "good_morning_both_awake";
        trigger = [
          {
            platform = "state";
            entity_id = "input_boolean.edmund_awake";
            to = "on";
          }
          {
            platform = "state";
            entity_id = "input_boolean.monica_awake";
            to = "on";
          }
        ];
        condition = [
          {
            condition = "state";
            entity_id = "input_boolean.edmund_awake";
            state = "on";
          }
          {
            condition = "state";
            entity_id = "input_boolean.monica_awake";
            state = "on";
          }
        ];
        action = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.good_morning";
          }
        ];
      }
    ];
  };
}
