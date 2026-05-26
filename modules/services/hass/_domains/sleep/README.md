# Sleep Domain

Alarm-driven circadian sleep lifecycle + Apple↔8Sleep sync + wake detection, with **manual/voice Good Morning**.

Owns: `input_boolean.goodnight`, `input_boolean.edmund_awake`, `input_boolean.monica_awake`

Decision record: [`../../docs/adr/0001-alarm-driven-circadian-sleep-lifecycle.md`](../../docs/adr/0001-alarm-driven-circadian-sleep-lifecycle.md)

## Alarm-Driven Circadian Flow

The sleep lifecycle is driven by Edmund's next iPhone alarm when Edmund is home. A five-minute homeostasis check runs between 8 PM and midnight, targets six 90-minute sleep cycles by default, and applies each phase once per night.

For a 7:30 AM wake time with the default 9h target:

```
Winding Down  →  Get Ready for Bed  →  Good Night  →  Sleep  →  Wake
(9:30 PM)        (10:05 PM)             (10:15 PM)     (10:30 PM) (7:30 AM)
```

Timing rules:

- **Sleep:** next alarm minus six 90-minute cycles (9h)
- **Good Night:** Sleep minus 15 minutes (fall-asleep buffer)
- **Get Ready for Bed:** Good Night minus 10 minutes (prep buffer)
- **Winding Down:** Sleep minus 60 minutes (circadian prelude)

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
- **Actions:** Deep sleep mode — everything quiet/off as appropriate

## Wake Detection (Tracking Only)

Wake detection automations still update:

- `input_boolean.edmund_awake`
- `input_boolean.monica_awake`

These booleans are tracking-only now (for observability/manual use).

## Good Morning

`scene.good_morning` is intentionally **not auto-triggered** by wake detection anymore.
Use voice/manual activation instead (e.g., Assist intent or Home app scene/script).

## Apple ↔ 8Sleep Sync

Two automations keep iPhone alarms and 8Sleep alarms in sync:

**iPhone → 8Sleep alarm sync:**

- Triggers when `sensor.edmunds_iphone_next_alarm` changes
- Calls `eight_sleep.set_one_off_alarm` on 8Sleep
- Skips alarms at 11am or later

**Sleep Focus off → dismiss 8Sleep alarm:**

- Triggers when iPhone focus turns off (6–9am)
- Calls 8Sleep `dismiss_alarm` + `side_off`
- Separate automations for Edmund and Monica

## Entity Reference

### 8Sleep

| Entity                                                 | Notes                          |
| ------------------------------------------------------ | ------------------------------ |
| `sensor.edmund_s_eight_sleep_side_sleep_stage`         | Service target for alarm calls |
| `switch.edmund_s_eight_sleep_next_alarm`               | Alarm switch                   |
| `binary_sensor.edmund_s_eight_sleep_side_bed_presence` | Bed presence (unreliable)      |
| `binary_sensor.monica_s_eight_sleep_side_bed_presence` | Bed presence (unreliable)      |

### iPhone Sensors

| Entity                                      | Notes                                                                      |
| ------------------------------------------- | -------------------------------------------------------------------------- |
| `sensor.edmunds_iphone_next_alarm`          | Next alarm datetime; primary source for circadian flow when Edmund is home |
| `sensor.monicas_iphone_next_alarm`          | Future fallback source when Edmund is away and Monica is home              |
| `binary_sensor.edmunds_iphone_focus`        | Any focus active (Sleep, DND, Work)                                        |
| `sensor.edmunds_iphone_battery_state`       | Charging / Not Charging                                                    |
| `sensor.edmunds_iphone_activity`            | Stationary / Walking / Unknown                                             |
| `sensor.edmunds_iphone_last_update_trigger` | Launch / Siri / Manual / Background Fetch                                  |

(Monica equivalents: replace `edmunds` with `monicas`)
