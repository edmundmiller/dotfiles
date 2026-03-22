# Sleep Domain

Bedtime progression + Apple↔8Sleep sync + wake detection, with **manual/voice Good Morning**.

Owns: `input_boolean.goodnight`, `input_boolean.edmund_awake`, `input_boolean.monica_awake`

## Three-Stage Bedtime Flow

```
Winding Down  →  In Bed  →  Sleep
(10:00 PM)       (bed presence)  (manual/future: audiobook stops)
```

### 1. Winding Down

- **Trigger:** 10:00 PM daily
- **Actions:** Goodnight toggle on, house mode → Night, blinds close, night light stays on for navigation
- **Scene:** Sets whitenoise off, AL sleep mode on

### 2. In Bed

- **Trigger:** Monica's bed presence on for 2 minutes
- **Actions:** All lights off, whitenoise on (audiobook time)

### 3. Sleep

- **Trigger:** Manual (future: audiobook stops or Sleep Focus activates)
- **Actions:** Deep sleep mode — everything quiet

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

| Entity                                      | Notes                                     |
| ------------------------------------------- | ----------------------------------------- |
| `sensor.edmunds_iphone_next_alarm`          | Next alarm datetime                       |
| `binary_sensor.edmunds_iphone_focus`        | Any focus active (Sleep, DND, Work)       |
| `sensor.edmunds_iphone_battery_state`       | Charging / Not Charging                   |
| `sensor.edmunds_iphone_activity`            | Stationary / Walking / Unknown            |
| `sensor.edmunds_iphone_last_update_trigger` | Launch / Siri / Manual / Background Fetch |

(Monica equivalents: replace `edmunds` with `monicas`)
