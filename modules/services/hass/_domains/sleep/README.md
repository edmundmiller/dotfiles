---
purpose: Document the Home Assistant sleep domain lifecycle and operator test paths.
applies_to: Sleep scheduling, bedtime cues, wake tracking, and Eight Sleep integration changes.
entrypoint: Start with wake_up_at.nix and the alarm-relative timing rules below.
verification: Run the sleep-domain Nix assertions and exercise the documented hidden test event.
update_when: Sleep timing, owned entities, integrations, or debug events change.
---

# Sleep Domain

Alarm-driven circadian sleep lifecycle + 8Sleep wake scheduling + wake detection, with **manual/voice Good Morning**.

Owns: `input_boolean.goodnight`, `input_boolean.edmund_awake`, `input_boolean.monica_awake`

Decision record: [`../../docs/adr/0001-alarm-driven-circadian-sleep-lifecycle.md`](../../docs/adr/0001-alarm-driven-circadian-sleep-lifecycle.md)

## Alarm-Driven Circadian Flow

The sleep lifecycle is currently driven by Edmund's next Eight Sleep smart alarm when Edmund is home. A five-minute homeostasis check runs between 8 PM and midnight, targets six 90-minute sleep cycles ending at the **start** of the smart-wake window, and applies each phase once per night.

For a 7:45 AM latest wake time with the default 30-minute smart-alarm window:

```
Winding Down  →  Get Ready for Bed  →  Good Night  →  Sleep  →  Smart Wake Window
(9:15 PM)        (9:50 PM)              (10:00 PM)    (10:15 PM) (7:15–7:45 AM)
```

Timing rules:

- **Latest Wake:** Eight Sleep alarm timestamp, or fallback latest wake time (7:45 AM weekdays / 8:00 AM weekends)
- **Ideal Wake:** Latest Wake minus 30 minutes (start of smart-alarm window)
- **Sleep:** Ideal Wake minus six 90-minute cycles (9h)
- **Good Night:** Sleep minus 15 minutes (fall-asleep buffer)
- **Get Ready for Bed:** Good Night minus 10 minutes (prep buffer)
- **Winding Down:** Sleep minus 60 minutes (circadian prelude)

### BUSY Bar bedtime progress

During the final 30 minutes before Good Night, Home Assistant draws a countdown and five six-minute checkpoints inside a framed track on the BUSY Bar through the LAN Canvas API. Completed checkpoints are cyan, the current checkpoint is amber, and upcoming checkpoints are dim gray. The drawing uses the namespaced application `home_assistant_bedtime`, priority 50, and 75-second element timeouts. BUSY/custom firmware activity at priority 90 takes precedence. The automation never calls the Matter `light.busy_bar` entity.

The automation redraws every minute from 8 PM through midnight and whenever its alarm, presence, or sleep-state inputs change. Outside the active window it deletes only the `home_assistant_bedtime` application, restoring the prior display.

For deterministic testing, fire `busy_bar_bedtime_test_tick` with ISO8601 `now` and `target` values. The event bypasses only the presence guard; the active-window and sleep-state guards still apply.

```yaml
event_type: busy_bar_bedtime_test_tick
event_data:
  now: "2026-08-02T22:45:00-05:00"
  target: "2026-08-02T23:00:00-05:00"
```

### Hidden debug tick

For deterministic testing without changing the NUC system clock, the homeostasis automation also listens for the hidden event `sleep_homeostasis_test_tick`. Fire it with an ISO8601 `now` value to exercise the same phase logic outside the real 5-minute time-pattern tick:

```yaml
event_type: sleep_homeostasis_test_tick
event_data:
  now: "2026-05-27T21:15:00-05:00"
```

The test tick still requires Edmund to be home, but bypasses the normal 8 PM–midnight wall-clock guard and uses `event_data.now` for all scheduler timestamp math.

### 1. Winding Down

- **Trigger:** Relative to calculated Sleep time, not fixed clock time
- **Intent:** Passive circadian cueing
- **Actions:** Soft dimming/warming only for now; no hard bedtime commitment

### 2. Get Ready for Bed

- **Trigger:** Relative to calculated Good Night time
- **Intent:** Active preparation before getting into bed
- **Actions:** House/person prep for bed

### 3. Good Night

- **Trigger:** Relative to calculated Sleep time, or manual/voice activation
- **Intent:** In-bed settling phase
- **Actions:** Bedroom-focused settling; turn off bedroom lights; leave non-bedroom state alone unless explicitly part of the scene
- **Alias note:** Historical/voice phrases such as “Ignite”, “Launch Sequence”, and the old **In Bed** path are retired; the canonical domain term is **Good Night**.

### 4. Sleep

- **Trigger:** Calculated Sleep time after the fall-asleep buffer
- **Intent:** Final asleep state
- **Actions:** Deep sleep mode — everything quiet/off as appropriate, including the dog fountain and plant light

## White noise follows bedtime playback

During `input_boolean.goodnight`, five continuous minutes of playback on either
`media_player.bathroom_nightstand_2` or `media_player.window_nightstand_2` turns on
the white-noise outlet. These are the Music Assistant entities: recorded BookPlayer
AirPlay sessions report `playing` here while the native HomePod entities remain
idle/off. BookPlayer reports its content as `music`, so the rule intentionally
recognizes bedroom audio during bedtime mode rather than matching book titles.

Both speakers paused, idle, or unavailable cancels the countdown; resuming starts
a fresh five minutes. Chapter metadata updates do not reset it. Playback already
running when bedtime mode starts also gets a full five minutes. No bed-presence,
heart-rate, or `sleep_done` gate is required. Good Morning cancels the countdown
and retains its existing outlet-off action. Turning the outlet off manually does
not restart it during uninterrupted playback, but a later playback session can.
Home Assistant restart or automation reload discards an in-progress countdown.

`../../_tests/test_bedtime_audio.py` exercises the exported Nix automation in an
isolated Home Assistant runtime with no physical integrations. It asserts the
five-minute setting, then accelerates the timer to one second for cancellation,
chapter-change, either-speaker, and non-bedtime playback checks. Pass the automation
JSON as its first argument using a Python environment with Home Assistant installed.

Export only this domain's automation from the repository root (no host evaluation):

```sh
nix-instantiate --eval --strict --json --expr '
  let
    config = (import ./modules/services/hass/_domains/sleep/default.nix {
      lib.mkAfter = x: x;
      pkgs.systemd = "/unused";
    }).services.home-assistant.config;
  in builtins.head (builtins.filter
    (a: a.id == "white_noise_with_bedtime_audiobook") config.automation)
' > /tmp/bedtime-audio-automation.json
python modules/services/hass/_tests/test_bedtime_audio.py /tmp/bedtime-audio-automation.json -v
```

## Wake Detection (Tracking Only)

Wake detection automations still update:

- `input_boolean.edmund_awake`
- `input_boolean.monica_awake`

These booleans are tracking-only now (for observability/manual use).

## Good Morning

`scene.good_morning` is intentionally **not auto-triggered** by wake detection anymore.
Use voice/manual activation instead (e.g., Assist intent or Home app scene/script).

## Apple / 8Sleep Integration

The iPhone → 8Sleep alarm sync path is intentionally declaratively disabled in Nix. iOS Home Assistant Companion does not expose a passive `sensor.<iphone>_next_alarm` entity like Android does, and `sensor.edmunds_iphone_next_alarm` does not exist in this HA instance.

Current active integrations:

**Evening Eight Sleep alarm refresh:**

- Runs every 2 minutes from 7:30–11pm while Edmund is home
- Calls `homeassistant.update_entity` for `sensor.edmund_s_eight_sleep_side_next_alarm`
- Keeps smart-alarm edits fresh during the bedtime decision window without polling all day

**Sleep Focus off → stop 8Sleep side:**

- Triggers when iPhone focus turns off (6–9am)
- Turns off the alarm switch and calls 8Sleep `side_off`
- Separate automations for Edmund and Monica

## Entity Reference

### 8Sleep

| Entity                                                 | Notes                                |
| ------------------------------------------------------ | ------------------------------------ |
| `sensor.edmund_s_eight_sleep_side_sleep_stage`         | Service target for alarm calls       |
| `sensor.edmund_s_eight_sleep_side_next_alarm`          | Latest wake / smart-alarm window end |
| `switch.edmund_s_eight_sleep_side_next_alarm`          | Alarm switch, currently unavailable  |
| `binary_sensor.edmund_s_eight_sleep_side_bed_presence` | Bed presence (unreliable)            |
| `binary_sensor.monica_s_eight_sleep_side_bed_presence` | Bed presence (unreliable)            |

### iPhone Sensors

| Entity                                      | Notes                                     |
| ------------------------------------------- | ----------------------------------------- |
| `binary_sensor.edmunds_iphone_focus`        | Any focus active (Sleep, DND, Work)       |
| `sensor.edmunds_iphone_battery_state`       | Charging / Not Charging                   |
| `sensor.edmunds_iphone_activity`            | Stationary / Walking / Unknown            |
| `sensor.edmunds_iphone_last_update_trigger` | Launch / Siri / Manual / Background Fetch |

(Monica equivalents: replace `edmunds` with `monicas`)
