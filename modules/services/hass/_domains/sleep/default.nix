# Sleep domain — bedtime progression, bed presence, wake detection (manual Good Morning)
#
# Owns the full sleep/wake lifecycle:
#   - input_boolean.goodnight (night mode toggle)
#   - input_boolean.edmund_awake / monica_awake (wake detection)
#   - Scenes: Winding Down → In Bed → Sleep → Good Morning
#   - Automations: bedtime, 8Sleep sync, wake detection
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
# NOTE: Wake detection is retained, but auto Good Morning is intentionally removed.
# Good Morning remains available as a scene for manual/voice activation.
{ lib, ... }:
let
  inherit (import ../../_lib.nix) ensureEnabled;

  # ── Per-person entity config ───────────────────────────────────────────
  edmund = {
    name = "Edmund";
    id = "edmund";
    # Use composite template sensor — see template.binary_sensor below
    bedPresence = "binary_sensor.edmund_bed_presence_reliable";
    rawBedPresence = "binary_sensor.edmund_s_eight_sleep_side_bed_presence";
    bedStateType = "sensor.edmund_s_eight_sleep_side_bed_state_type";
    heartRate = "sensor.edmund_s_eight_sleep_side_heart_rate";
    focus = "binary_sensor.edmunds_iphone_focus";
    battery = "sensor.edmunds_iphone_battery_state";
    activity = "sensor.edmunds_iphone_activity";
    updateTrigger = "sensor.edmunds_iphone_last_update_trigger";
    awake = "input_boolean.edmund_awake";
    alarmSwitch = "switch.edmund_s_eight_sleep_next_alarm";
    sleepStage = "sensor.edmund_s_eight_sleep_side_sleep_stage";
  };

  monica = {
    name = "Monica";
    id = "monica";
    bedPresence = "binary_sensor.monica_bed_presence_reliable";
    rawBedPresence = "binary_sensor.monica_s_eight_sleep_side_bed_presence";
    bedStateType = "sensor.monica_s_eight_sleep_side_bed_state_type";
    heartRate = "sensor.monica_s_eight_sleep_side_heart_rate";
    focus = "binary_sensor.monicas_iphone_focus";
    battery = "sensor.monicas_iphone_battery_state";
    activity = "sensor.monicas_iphone_activity";
    updateTrigger = "sensor.monicas_iphone_last_update_trigger";
    awake = "input_boolean.monica_awake";
    alarmSwitch = "switch.monica_s_eight_sleep_next_alarm";
    sleepStage = "sensor.monica_s_eight_sleep_side_sleep_stage";
  };

  # Reliable bed presence: bed_state_type active OR (raw presence ON AND HR available)
  # Survives cloud session ending early because bed_state_type persists.
  mkReliableBedPresence = p: {
    name = "${p.name} Bed Presence Reliable";
    unique_id = "${p.id}_bed_presence_reliable";
    icon = "mdi:bed";
    device_class = "occupancy";
    # bed_state_type != 'off' means Eight Sleep thinks someone is in bed
    # Raw presence OR heart rate available as fallback confirmation
    state = ''
      {{ states('${p.bedStateType}') not in ['off', 'unknown', 'unavailable']
         or (is_state('${p.rawBedPresence}', 'on')
             and states('${p.heartRate}') not in ['unknown', 'unavailable', '0']) }}
    '';
    # Only update every 30s — avoids flapping on sensor update boundaries
    delay_off.seconds = 30;
  };

  # ── Automation generators ──────────────────────────────────────────────

  # Sleep Focus off 6–9am → cancel + dismiss 8Sleep alarm, turn off side
  # Covers two cases: alarm hasn't fired yet (switch off) and actively ringing (dismiss).
  mkSleepFocusOff = p: {
    alias = "Sleep Focus Off - Stop ${p.name} 8Sleep";
    id = "sleep_focus_off_stop_${p.id}";
    description = "${p.name} turns off Sleep Focus 6–9am → cancel alarm, turn off bed";
    trigger = {
      platform = "state";
      entity_id = p.focus;
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
        entity_id = "input_boolean.goodnight";
        state = "on";
      }
    ];
    action = [
      # Cancel if not yet ringing
      {
        action = "switch.turn_off";
        target.entity_id = p.alarmSwitch;
      }
      # Dismiss if actively ringing
      {
        action = "eight_sleep.alarm_dismiss";
        target.entity_id = p.sleepStage;
      }
      # Stop heating/cooling
      {
        action = "eight_sleep.side_off";
        target.entity_id = p.sleepStage;
      }
    ];
  };

  # Wake detection only — mark per-person awake booleans.
  # Good Morning is intentionally not auto-triggered from these booleans.
  mkWakeDetection = p: {
    alias = "${p.name} is awake";
    id = "${p.id}_awake_detection";
    trigger = [
      {
        # Composite sensor: stable, survives Eight Sleep cloud oddities
        platform = "state";
        entity_id = p.bedPresence;
        to = "off";
        "for".minutes = 2;
      }
      {
        # Raw Eight Sleep bed-presence can flap, but catches real wake-ups
        # earlier when bed_state_type lags. Require longer off duration.
        platform = "state";
        entity_id = p.rawBedPresence;
        to = "off";
        "for".minutes = 5;
      }
      {
        platform = "state";
        entity_id = p.focus;
        to = "off";
      }
      {
        platform = "state";
        entity_id = p.battery;
        from = "Charging";
        to = "Not Charging";
      }
      {
        platform = "state";
        entity_id = p.activity;
        to = "Walking";
      }
      {
        platform = "template";
        value_template = "{{ states('${p.updateTrigger}') in ['Launch', 'Siri', 'Manual'] }}";
      }
    ];
    condition = [
      {
        condition = "time";
        after = "07:00:00";
        before = "12:00:00";
      }
      {
        condition = "state";
        entity_id = "input_boolean.goodnight";
        state = "on";
      }
      {
        condition = "state";
        entity_id = p.awake;
        state = "off";
      }
    ];
    action = [
      {
        action = "input_boolean.turn_on";
        target.entity_id = p.awake;
      }
    ];
  };

in
{
  services.home-assistant.config = {
    # ── Template sensors (reliable bed presence) ─────────────────────────
    # Composites that survive Eight Sleep cloud session ending prematurely.
    # See: https://github.com/lukas-clarke/eight_sleep/issues/114
    template = lib.mkAfter [
      {
        binary_sensor = [
          (mkReliableBedPresence edmund)
          (mkReliableBedPresence monica)
        ];
      }
    ];

    # ── Input helpers (sleep/wake lifecycle) ──────────────────────────────
    input_boolean = {
      goodnight = {
        name = "Goodnight";
        icon = "mdi:weather-night";
      };
      edmund_awake = {
        name = "Edmund Awake";
        icon = "mdi:sleep-off";
      };
      monica_awake = {
        name = "Monica Awake";
        icon = "mdi:sleep-off";
      };
    };

    # ── Scenes ───────────────────────────────────────────────────────────
    scene = lib.mkAfter [
      # Stage 1: Get ready for bed
      {
        name = "Winding Down";
        icon = "mdi:weather-night";
        entities = {
          "input_boolean.goodnight" = "on";
          "input_boolean.edmund_awake" = "off"; # reset wake tracking
          "input_boolean.monica_awake" = "off";
          "cover.smartwings_window_covering" = "closed";
          "media_player.tv" = "off";
          "switch.adaptive_lighting_sleep_mode_living_space" = "on";

          # Main lights off
          "light.essentials_a19_a60" = "off"; # Trashcan
          "light.essentials_a19_a60_2" = "off"; # Dishwasher
          "light.essentials_a19_a60_3" = "off"; # Bathroom Nightstand
          "light.essentials_a19_a60_4" = "off"; # Window Nightstand
          "light.essentials_a19_a60_5" = "off"; # Wall Lamp
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
          "switch.adaptive_lighting_sleep_mode_living_space" = "on";
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
          "select.master_suite_current_mode" = "sleep";
          "switch.adaptive_lighting_sleep_mode_living_space" = "on";
          "switch.eve_energy_20ebu4101" = "on"; # Whitenoise stays
          "switch.desk_monitor" = "off";
          "switch.desk_pop" = "off";
          "cover.smartwings_window_covering" = "closed";
          "media_player.tv" = "off";
          "light.essentials_a19_a60" = "off";
          "light.essentials_a19_a60_2" = "off";
          "light.essentials_a19_a60_3" = "off"; # Bathroom Nightstand
          "light.essentials_a19_a60_4" = "off"; # Window Nightstand
          "light.essentials_a19_a60_5" = "off"; # Wall Lamp
          "light.nanoleaf_multicolor_floor_lamp" = "off";
          "light.nanoleaf_multicolor_hd_ls" = "off";
          "light.smart_night_light_w" = "off";
        };
      }
      # Wake — end of sleep cycle
      # Turns off night mode, opens blinds, lights on for overcast mornings.
      # Mid-morning (ambient.nix) follows up at sunrise+2h to kill lights
      # once natural light is sufficient.
      {
        name = "Good Morning";
        icon = "mdi:weather-sunny";
        entities = {
          "input_boolean.goodnight" = "off";
          "input_boolean.edmund_awake" = "off"; # reset for next night
          "input_boolean.monica_awake" = "off";
          "select.master_suite_current_mode" = "home";
          # Cover scenes require state string + current_position attribute.
          # position= is ignored in scene reproduction for this cover.
          "cover.smartwings_window_covering" = {
            state = "open";
            current_position = 20;
          };
          "switch.eve_energy_20ebu4101" = "off"; # whitenoise machine
          "switch.adaptive_lighting_sleep_mode_living_space" = "off";
          "switch.desk_monitor" = "on";
          "switch.desk_pop" = "on";

          # Lights on — AL handles color temp/brightness for time of day.
          # Mid-morning scene (sunrise+2h) turns these off when natural
          # light is enough.
          "light.essentials_a19_a60" = "on"; # Kitchen (Trashcan)
          "light.essentials_a19_a60_2" = "on"; # Kitchen (Dishwasher)
          "light.essentials_a19_a60_5" = "on"; # Wall Lamp
          "light.nanoleaf_multicolor_floor_lamp" = "on"; # Couch Lamp
          "light.nanoleaf_multicolor_hd_ls" = "on"; # Edmund Desk
        };
      }
    ];

    # ── Scripts ──────────────────────────────────────────────────────────
    script = lib.mkAfter {
      # Siri/HomeKit entrypoint: "Hey Siri, goodnight" → run sleep scene
      goodnight = {
        alias = "Goodnight";
        icon = "mdi:weather-night";
        sequence = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.winding_down";
          }
        ];
      };

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

    # ── Automations ──────────────────────────────────────────────────────
    automation = lib.mkAfter (ensureEnabled [
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

      # Keep nightstands off whenever goodnight mode is on
      {
        alias = "Goodnight keeps bedroom lamps off";
        id = "goodnight_keep_nightstands_off";
        description = "During goodnight mode, force nightstand + wall lamps off";
        trigger = [
          {
            platform = "state";
            entity_id = "input_boolean.goodnight";
            to = "on";
          }
          {
            platform = "state";
            entity_id = [
              "light.essentials_a19_a60_3"
              "light.essentials_a19_a60_4"
              "light.essentials_a19_a60_5"
            ];
            to = "on";
          }
        ];
        condition = {
          condition = "state";
          entity_id = "input_boolean.goodnight";
          state = "on";
        };
        action = [
          {
            action = "light.turn_off";
            target.entity_id = [
              "light.essentials_a19_a60_3"
              "light.essentials_a19_a60_4"
              "light.essentials_a19_a60_5"
            ];
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
        # Guardrails: only allow this bedtime stage at night while in goodnight mode.
        # Prevents morning re-triggers when bed presence briefly flips back to "on".
        condition = [
          {
            condition = "state";
            entity_id = "input_boolean.goodnight";
            state = "on";
          }
          {
            condition = "time";
            after = "21:00:00";
            before = "06:00:00";
          }
        ];
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

      # ── Apple ↔ 8Sleep integration ─────────────────────────────────────

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

      # Per-person: Sleep Focus off 6–9am → cancel + dismiss 8Sleep alarm
      (mkSleepFocusOff edmund)
      (mkSleepFocusOff monica)

      # Wake detection retained for awake state tracking only.
      (mkWakeDetection edmund)
      (mkWakeDetection monica)

      # Auto Good Morning intentionally disabled.
    ]);
  };
}
