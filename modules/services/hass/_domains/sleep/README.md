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

### iPhone bedtime Live Activity

Scheduled phases update one `edmund-bedtime` Live Activity on Edmund's iPhone:
Winding Down (0%), Get Ready for Bed (33%), Good Night (67%), and Sleep (100%).
Progress represents scheduled phases, not verified completion of personal tasks.
The static title is **Bedtime**; each update includes the phase instructions and
target times. No chronometer is set because iOS replaces the message with its
timer. Updates replace the previous banners and arrive silently on phase changes,
not on every scheduler tick. The activity is cleared at midnight, when the
scheduling window closes. Manual/voice scripts do not send these phase updates.

Requires Home Assistant Core 2026.7+, iOS 17.2+, a Companion app supporting Live
Activities, and Live Activities enabled for Home Assistant on the phone. The phone
must reach HA for the token handshake. See the
[Companion documentation](https://companion.home-assistant.io/docs/notifications/live-activities/).
Monica's routine remains separate and is not configured here yet.

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

These booleans combine bed presence, charging, activity, explicit phone updates,
and Monica's generic Focus-off signal. Edmund's Focus transitions never mark him
awake, so leaving Sleep Focus cannot indirectly start Good Morning.

## Good Morning

Manual/voice `script.good_morning` applies the scene immediately, even if Edmund's
Focus report is stale `Sleep`, `unknown`, unavailable, or missing. An explicit
request takes precedence over phone telemetry. HomeKit, Assist, the dashboard,
and the voice webhook continue to use this same script.

Automatic Good Morning remains separately guarded: from 7 AM to noon, every
resident who is home must be marked awake, goodnight must be on, and Edmund's
Focus must not be `Sleep`, `unknown`, or `unavailable` while he is home. Blocked
automatic calls are discarded, not queued. Leaving Sleep Focus does not run Good
Morning or re-evaluate an earlier wake signal. Activate the script, not its
internal immediate-state scene. The script waits ten
minutes before turning on the desk monitor and desk POP switches to avoid the
bright display at wake-up. Activating Good Morning again restarts the delay; a
bedtime activation cancels the pending power-on.

`../../_tests/test_good_morning.py` runs the exported sleep configuration in an
isolated HA runtime, without physical integrations. It checks manual activation
with Sleep, unknown, unavailable, Work, empty, and missing Focus reports, scene
application, DJ dispatch, delayed desk power, and the goodnight re-entry guard.
Export the domain without evaluating the NUC host:

```sh
nix-instantiate --eval --strict --json --expr '
  let lib = {
    mkAfter = x: x;
    optional = b: x: if b then [x] else [];
  }; in (import ./modules/services/hass/_domains/sleep/default.nix {
    inherit lib;
    pkgs.systemd = "/unused";
  }).services.home-assistant.config
' > /tmp/good-morning-config.json
python modules/services/hass/_tests/test_good_morning.py /tmp/good-morning-config.json -v
```

### iPhone Focus name reporting

`sensor.edmunds_iphone_focus_name` belongs to Companion's `mobile_app` integration,
not a Nix template or a custom Shortcut. iOS exposes only whether a Focus is active;
the name comes from a per-Focus Home Assistant **Report Focus name** filter.
Opening Companion refreshes sensors but cannot discover an unmapped Focus name.

On Edmund's iPhone:

1. In Home Assistant Companion settings, open Sensors → Focus name, enable the
   sensor, grant Focus permission, and configure names `Sleep` and `Work`.
2. In iOS Settings → Focus → Sleep → Focus Filters, add Home Assistant's
   **Report Focus name** filter and select `Sleep`.
3. Repeat for Work, selecting `Work`. Each other Focus needing a name needs its
   own mapping. Allow Focus-status sharing with Home Assistant.
4. When safe to exercise the existing Focus-triggered bed actions, switch Sleep
   → Work → all Focus off and inspect the HA sensor. Expect `Sleep` / `true`,
   `Work` / `true`, then empty string / `false` for state / `Is focused`.

An empty name can also mean an active but unnamed Focus; inspect `Is focused`
rather than treating an empty string as proof that all Focus modes are off.
Do not reset the HA sensor on a timer or replace its name with the generic Focus
boolean: neither establishes that Sleep ended. Phone configuration/delivery must
be verified on the phone; the server-side manual bypass does not repair it.

Upstream contracts: [Focus filter intent](https://github.com/home-assistant/iOS/blob/master/Sources/App/Settings/Focus/FocusNameFocusFilterAppIntent.swift),
[sensor state and attributes](https://github.com/home-assistant/iOS/blob/master/Sources/Shared/API/Webhook/Sensors/FocusNameSensor.swift),
and [Focus report reconciliation](https://github.com/home-assistant/iOS/blob/master/Sources/Shared/Environment/FocusReport.swift).

## Apple / 8Sleep Integration

The iPhone → 8Sleep alarm sync path is intentionally declaratively disabled in Nix. iOS Home Assistant Companion does not expose a passive `sensor.<iphone>_next_alarm` entity like Android does, and `sensor.edmunds_iphone_next_alarm` does not exist in this HA instance.

Current active integrations:

**Evening Eight Sleep alarm refresh:**

- Runs every 2 minutes from 7:30–11pm while Edmund is home
- Calls `homeassistant.update_entity` for `sensor.edmund_s_eight_sleep_side_next_alarm`
- Keeps smart-alarm edits fresh during the bedtime decision window without polling all day

**Sleep Focus off → stop 8Sleep side:**

- Edmund triggers only when `sensor.edmunds_iphone_focus_name` leaves `Sleep`;
  Monica retains the generic Focus-off trigger until named reporting is configured
- Runs from 6–9am
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

| Entity                                      | Notes                                            |
| ------------------------------------------- | ------------------------------------------------ |
| `sensor.edmunds_iphone_focus_name`          | Explicitly mapped Focus name (Sleep/Work)        |
| `binary_sensor.edmunds_iphone_focus`        | Any Focus active; not used for Edmund wake logic |
| `sensor.edmunds_iphone_battery_state`       | Charging / Not Charging                          |
| `sensor.edmunds_iphone_activity`            | Stationary / Walking / Unknown                   |
| `sensor.edmunds_iphone_last_update_trigger` | Launch / Siri / Manual / Background Fetch        |

(Monica equivalents: replace `edmunds` with `monicas`)
