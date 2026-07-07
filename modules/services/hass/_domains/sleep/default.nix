# Sleep domain — alarm-driven circadian sleep lifecycle, wake detection, manual Good Morning
#
# Owns the full sleep/wake lifecycle:
#   - input_boolean.goodnight (night mode toggle)
#   - input_boolean.edmund_awake / monica_awake (wake detection)
#   - Circadian phase helpers (applied once per alarm schedule)
#   - Scenes: Winding Down → Get Ready for Bed → Good Night → Sleep → Good Morning
#   - Automations: circadian homeostasis, 8Sleep focus-off dismissal, wake detection
#
# Alarm-driven flow (see modules/services/hass/docs/adr/0001-*):
#   Winding Down      ← Sleep - 60 minutes (soft circadian cueing)
#   Get Ready for Bed ← Good Night - 10 minutes
#   Good Night        ← Sleep - 15 minutes (fall-asleep buffer)
#   Sleep             ← Eight Sleep ideal wake - 6 × 90-minute cycles
#
# Homeostasis checks run every 5 minutes between 8 PM and midnight when
# Edmund is home. Each phase is applied once per next-alarm schedule.
#
# Apple / 8Sleep integration:
#   iOS next-alarm sensor sync is declaratively disabled; no passive iPhone alarm entity exists.
#   Sleep Focus off 6–9am → dismiss 8Sleep alarm + side_off (manual wake = skip alarm)
#
# Entity name notes (verify in HA dev tools > States if IDs change):
#   8Sleep service target: sensor.edmund_s_eight_sleep_side_sleep_stage
#   8Sleep next alarm: sensor.edmund_s_eight_sleep_side_next_alarm (timestamp)
#   8Sleep next alarm switch: switch.edmund_s_eight_sleep_side_next_alarm
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

    # Reliable composite helper owned by this module; true when 8Sleep still
    # indicates bed activity even if raw cloud presence drops out.
    bedPresence = "binary_sensor.edmund_bed_presence_reliable";

    # Raw Eight Sleep entities. Presence is flaky after cloud sessions end;
    # bed_state_type and heart_rate are used to keep bed-presence tracking sane.
    rawBedPresence = "binary_sensor.edmund_s_eight_sleep_side_bed_presence";
    bedStateType = "sensor.edmund_s_eight_sleep_side_bed_state_type";
    heartRate = "sensor.edmund_s_eight_sleep_side_heart_rate";

    # iPhone companion app entities. Focus is generic: on means any Focus mode,
    # not specifically Sleep Focus. updateTrigger helps distinguish manual/Siri
    # updates from background updates in wake-detection heuristics.
    focus = "binary_sensor.edmunds_iphone_focus";
    battery = "sensor.edmunds_iphone_battery_state";
    activity = "sensor.edmunds_iphone_activity";
    updateTrigger = "sensor.edmunds_iphone_last_update_trigger";

    # Sleep-domain helper tracking whether wake heuristics saw Edmund awake.
    awake = "input_boolean.edmund_awake";

    # Eight Sleep alarm/service entities. sleepStage is the service target for
    # eight_sleep.set_one_off_alarm / dismiss_alarm / side_off calls.
    alarmSwitch = "switch.edmund_s_eight_sleep_next_alarm";
    sleepStage = "sensor.edmund_s_eight_sleep_side_sleep_stage";
  };

  monica = {
    name = "Monica";
    id = "monica";

    # Reliable composite helper owned by this module; same semantics as Edmund.
    bedPresence = "binary_sensor.monica_bed_presence_reliable";

    # Raw Eight Sleep entities.
    rawBedPresence = "binary_sensor.monica_s_eight_sleep_side_bed_presence";
    bedStateType = "sensor.monica_s_eight_sleep_side_bed_state_type";
    heartRate = "sensor.monica_s_eight_sleep_side_heart_rate";

    # iPhone companion app entities; focus is generic, not Sleep-specific.
    focus = "binary_sensor.monicas_iphone_focus";
    battery = "sensor.monicas_iphone_battery_state";
    activity = "sensor.monicas_iphone_activity";
    updateTrigger = "sensor.monicas_iphone_last_update_trigger";

    # Sleep-domain helper tracking whether wake heuristics saw Monica awake.
    awake = "input_boolean.monica_awake";

    # Eight Sleep alarm/service entities.
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

  # Sleep Focus off 6–9am → cancel 8Sleep alarm, turn off side
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
  imports = [ ./wake_up_at.nix ];

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
    input_text.sleep_schedule_key = {
      name = "Sleep Schedule Key";
      icon = "mdi:calendar-clock";
    };

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
      winding_down_done = {
        name = "Winding Down Done";
        icon = "mdi:weather-night";
      };
      get_ready_for_bed_done = {
        name = "Get Ready For Bed Done";
        icon = "mdi:bed-clock";
      };
      goodnight_done = {
        name = "Good Night Done";
        icon = "mdi:bed";
      };
      sleep_done = {
        name = "Sleep Done";
        icon = "mdi:sleep";
      };
    };

    # ── Scenes ───────────────────────────────────────────────────────────
    scene = lib.mkAfter [
      # Passive circadian prelude. Internal only; not exposed to HomeKit.
      {
        name = "Winding Down";
        icon = "mdi:weather-night";
        entities = {
          "input_boolean.edmund_awake" = "off";
          "input_boolean.monica_awake" = "off";
          "cover.smartwings_window_covering" = "closed";
          "switch.adaptive_lighting_sleep_mode_living_space" = "on";

          # Keep a low-light ambience while winding down; AL sleep mode makes these warm/dim.
          "light.essentials_a19_a60" = "off"; # Trashcan
          "light.essentials_a19_a60_2" = "off"; # Dishwasher
          "light.essentials_a19_a60_3" = "on"; # Bathroom Nightstand
          "light.essentials_a19_a60_4" = "on"; # Window Nightstand
          "light.essentials_a19_a60_5" = "on"; # Wall Lamp
          "light.nanoleaf_multicolor_floor_lamp" = "on"; # Couch Lamp
          "light.nanoleaf_multicolor_hd_ls" = "off"; # Edmund Desk
          "light.smart_night_light_w" = "on"; # Night light: navigate to bed
        };
      }

      # First active bedtime prep phase. Voice/HomeKit-facing.
      {
        name = "Get Ready for Bed";
        icon = "mdi:bed-clock";
        entities = {
          "input_boolean.goodnight" = "on";
          "input_boolean.edmund_awake" = "off";
          "input_boolean.monica_awake" = "off";
          "cover.smartwings_window_covering" = "closed";
          "switch.adaptive_lighting_sleep_mode_living_space" = "on";
          "light.essentials_a19_a60" = "off";
          "light.essentials_a19_a60_2" = "off";
          "light.essentials_a19_a60_3" = "on";
          "light.essentials_a19_a60_4" = "on";
          "light.essentials_a19_a60_5" = "on";
          "light.nanoleaf_multicolor_floor_lamp" = "on";
          "light.nanoleaf_multicolor_hd_ls" = "off";
          "light.smart_night_light_w" = "on";
        };
      }

      # In-bed settling phase. Retires old In Bed/Ignite naming.
      {
        name = "Good Night";
        icon = "mdi:bed";
        entities = {
          "input_boolean.goodnight" = "on";
          "select.master_suite_current_mode" = "sleep";
          "switch.adaptive_lighting_sleep_mode_living_space" = "on";
          "switch.eve_energy_20ebu4101" = "off"; # Whitenoise waits for final Sleep phase
          "cover.smartwings_window_covering" = "closed";
          "light.essentials_a19_a60" = "off";
          "light.essentials_a19_a60_2" = "off";
          "light.essentials_a19_a60_3" = "off";
          "light.essentials_a19_a60_4" = "off";
          "light.essentials_a19_a60_5" = "off";
          "light.nanoleaf_multicolor_floor_lamp" = "off";
          "light.nanoleaf_multicolor_hd_ls" = "off";
          "light.smart_night_light_w" = "off";
        };
      }

      # Final asleep state. Internal only; not exposed to HomeKit/webhooks.
      {
        name = "Sleep";
        icon = "mdi:sleep";
        entities = {
          "input_boolean.goodnight" = "on";
          "select.master_suite_current_mode" = "sleep";
          "switch.adaptive_lighting_sleep_mode_living_space" = "on";
          "switch.eve_energy_20ebu4101" = "off"; # Whitenoise waits for sleep_done + both bed-presence signals
          "switch.desk_monitor" = "off";
          "switch.desk_pop" = "off";
          "cover.smartwings_window_covering" = "closed";
          "light.essentials_a19_a60" = "off";
          "light.essentials_a19_a60_2" = "off";
          "light.essentials_a19_a60_3" = "off";
          "light.essentials_a19_a60_4" = "off";
          "light.essentials_a19_a60_5" = "off";
          "light.nanoleaf_multicolor_floor_lamp" = "off";
          "light.nanoleaf_multicolor_hd_ls" = "off";
          "light.smart_night_light_w" = "off";
        };
      }

      # Wake — end of sleep cycle. Resets schedule helpers for the next night.
      {
        name = "Good Morning";
        icon = "mdi:weather-sunny";
        entities = {
          "input_boolean.goodnight" = "off";
          "input_boolean.edmund_awake" = "off";
          "input_boolean.monica_awake" = "off";
          "input_boolean.winding_down_done" = "off";
          "input_boolean.get_ready_for_bed_done" = "off";
          "input_boolean.goodnight_done" = "off";
          "input_boolean.sleep_done" = "off";
          "input_text.sleep_schedule_key" = "";
          "select.master_suite_current_mode" = "home";
          "cover.smartwings_window_covering" = {
            state = "open";
            current_position = 20;
          };
          "switch.eve_energy_20ebu4101" = "off";
          "switch.adaptive_lighting_sleep_mode_living_space" = "off";
          "switch.desk_monitor" = "on";
          "switch.desk_pop" = "on";
          "light.essentials_a19_a60" = "on";
          "light.essentials_a19_a60_2" = "on";
          "light.essentials_a19_a60_5" = "on";
          "light.nanoleaf_multicolor_floor_lamp" = "on";
          "light.nanoleaf_multicolor_hd_ls" = "on";
        };
      }
    ];

    # ── Scripts ──────────────────────────────────────────────────────────
    script = lib.mkAfter {
      # Siri/HomeKit entrypoints. Sleep remains internal only.
      get_ready_for_bed = {
        alias = "Get Ready For Bed";
        icon = "mdi:bed-clock";
        sequence = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.get_ready_for_bed";
          }
          {
            action = "script.tv_off_if_on";
          }
          {
            action = "input_boolean.turn_on";
            target.entity_id = "input_boolean.get_ready_for_bed_done";
          }
        ];
      };

      goodnight = {
        alias = "Good Night";
        icon = "mdi:bed";
        sequence = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.good_night";
          }
          {
            action = "script.tv_off_if_on";
          }
          {
            action = "input_boolean.turn_on";
            target.entity_id = "input_boolean.goodnight_done";
          }
        ];
      };

      sleep = {
        alias = "Sleep";
        icon = "mdi:sleep";
        sequence = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.sleep";
          }
          {
            action = "script.tv_off_if_on";
          }
          {
            action = "input_boolean.turn_on";
            target.entity_id = "input_boolean.sleep_done";
          }
        ];
      };

      good_morning = {
        alias = "Good Morning";
        icon = "mdi:weather-sunny";
        sequence = [
          {
            action = "scene.turn_on";
            target.entity_id = "scene.good_morning";
          }
          {
            action = "input_boolean.turn_off";
            target.entity_id = [
              "input_boolean.winding_down_done"
              "input_boolean.get_ready_for_bed_done"
              "input_boolean.goodnight_done"
              "input_boolean.sleep_done"
            ];
          }
          {
            action = "input_text.set_value";
            target.entity_id = "input_text.sleep_schedule_key";
            data.value = "";
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
      # Siri Shortcut webhooks. Sleep is deliberately not voice-facing.
      {
        alias = "Voice Webhook - Get Ready for Bed";
        id = "voice_webhook_get_ready_for_bed";
        trigger = {
          platform = "webhook";
          webhook_id = "ha_voice_00671127fbfa48e8afa9fe24bbf32b3e";
          allowed_methods = [ "POST" ];
          local_only = false;
        };
        action = [
          {
            action = "script.turn_on";
            target.entity_id = "script.get_ready_for_bed";
          }
        ];
      }
      {
        alias = "Voice Webhook - Goodnight";
        id = "voice_webhook_goodnight";
        trigger = {
          platform = "webhook";
          webhook_id = "ha_voice_5d3987a447ff4cb3bb5e9df5b9f072c6";
          allowed_methods = [ "POST" ];
          local_only = false;
        };
        action = [
          {
            action = "script.turn_on";
            target.entity_id = "script.goodnight";
          }
        ];
      }
      {
        alias = "Voice Webhook - Good Morning";
        id = "voice_webhook_good_morning";
        trigger = {
          platform = "webhook";
          webhook_id = "ha_voice_4ddb9377a08745e185cc5bbff25cc06a";
          allowed_methods = [ "POST" ];
          local_only = false;
        };
        action = [
          {
            action = "script.turn_on";
            target.entity_id = "script.good_morning";
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

      # White noise starts only after the final Sleep phase and both 8Sleep sides
      # report reliable bed presence. This avoids turning it on while one person
      # is still up, even if the alarm-relative schedule reaches Sleep time.
      {
        alias = "White noise after both in bed";
        id = "white_noise_after_both_in_bed";
        mode = "single";
        trigger = [
          {
            platform = "state";
            entity_id = "input_boolean.sleep_done";
            to = "on";
          }
          {
            platform = "state";
            entity_id = "binary_sensor.edmund_bed_presence_reliable";
            to = "on";
          }
          {
            platform = "state";
            entity_id = "binary_sensor.monica_bed_presence_reliable";
            to = "on";
          }
        ];
        condition = [
          {
            condition = "state";
            entity_id = "input_boolean.goodnight";
            state = "on";
          }
          {
            condition = "state";
            entity_id = "input_boolean.sleep_done";
            state = "on";
          }
          {
            condition = "state";
            entity_id = "binary_sensor.edmund_bed_presence_reliable";
            state = "on";
          }
          {
            condition = "state";
            entity_id = "binary_sensor.monica_bed_presence_reliable";
            state = "on";
          }
          {
            condition = "state";
            entity_id = "switch.eve_energy_20ebu4101";
            state = "off";
          }
        ];
        action = [
          {
            action = "switch.turn_on";
            target.entity_id = "switch.eve_energy_20ebu4101";
          }
        ];
      }

      # ── Apple / 8Sleep integration ─────────────────────────────────────

      # Kept declaratively disabled while we investigate whether there is a
      # usable iOS alarm bridge. iOS HA Companion does not currently expose the
      # Android-style `sensor.<phone>_next_alarm`; `sensor.edmunds_iphone_next_alarm`
      # is absent in this HA instance. If a Shortcut/helper bridge is added,
      # flip initial_state back to true and update the trigger/source entity.
      {
        alias = "Sync iPhone Alarm to 8Sleep";
        id = "sync_iphone_alarm_8sleep";
        initial_state = false;
        description = "Disabled: no passive iOS next-alarm entity currently exists";
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
            # Ignore alarms set for 11am or later — those aren't sleep alarms.
            value_template = "{{ (states('sensor.edmunds_iphone_next_alarm') | as_datetime | as_local).hour < 11 }}";
          }
        ];
        action = [
          {
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
