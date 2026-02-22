# Sleep Domain

Bedtime progression, bed presence, Apple↔8Sleep sync, and wake detection.

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

## Apple ↔ 8Sleep Sync

Two automations keep iPhone alarms and 8Sleep alarms in sync:

**iPhone → 8Sleep alarm sync:**
- Triggers when `sensor.edmunds_iphone_next_alarm` changes
- Calls `eight_sleep.set_one_off_alarm` on 8Sleep
- Only syncs if new alarm is within 24 hours

**Sleep Focus off → dismiss 8Sleep alarm:**
- Triggers when iPhone focus turns off (6–9am)
- Calls 8Sleep `dismiss_alarm` + `side_off`
- Separate automations for Edmund and Monica

## Wake Detection State Machine

Uses `input_boolean.edmund_awake` / `monica_awake` to track who's up.
Good Morning fires when **both** are on.

### Reset
- Winding Down scene sets both to `off`
- Good Morning scene also resets both (prevents stale state next night)

### Awake Signals

Any one of these during Night mode marks that person as awake:

| Signal | Entity pattern | What it means |
| --- | --- | --- |
| Bed presence off (2 min) | `binary_sensor.*_eight_sleep_side_bed_presence` | Physically out of bed (unreliable) |
| Focus off | `binary_sensor.*_iphone_focus` | Turned off any focus mode |
| Battery: Charging → Not Charging | `sensor.*_iphone_battery_state` | Picked phone off charger |
| Activity = Walking | `sensor.*_iphone_activity` | Up and moving around |
| Active phone use | `sensor.*_iphone_last_update_trigger` to Launch/Siri/Manual | Deliberate phone interaction (not Background Fetch) |

### Flow

```
Night mode active
  │
  ├── Person A wakes up
  │     └── Any signal fires → edmund_awake = on
  │         └── Check: both awake? No → wait
  │
  └── Person B wakes up (minutes to hours later)
        └── Any signal fires → monica_awake = on
            └── Check: both awake? Yes → Good Morning scene
                  ├── Blinds open 20%
                  ├── Goodnight toggle off
                  ├── House mode → Home
                  └── Reset both awake booleans
```

### Why Multiple Signals

No single sensor is reliable:
- **Generic focus** can't distinguish Sleep from Work/DND
- **8Sleep bed presence** is flaky
- **Battery** only works if phone was on charger
- **Activity/update trigger** depends on companion app reporting

Redundancy ensures the first real morning activity is caught. The Night mode
condition prevents all of these from false-triggering during the day.

## Entity Reference

### 8Sleep
| Entity | Notes |
| --- | --- |
| `sensor.edmund_s_eight_sleep_side_sleep_stage` | Service target for alarm calls |
| `switch.edmund_s_eight_sleep_next_alarm` | Alarm switch |
| `binary_sensor.edmund_s_eight_sleep_side_bed_presence` | Bed presence (unreliable) |
| `binary_sensor.monica_s_eight_sleep_side_bed_presence` | Bed presence (unreliable) |

### iPhone Sensors
| Entity | Notes |
| --- | --- |
| `sensor.edmunds_iphone_next_alarm` | Next alarm datetime |
| `binary_sensor.edmunds_iphone_focus` | Any focus active (Sleep, DND, Work) |
| `sensor.edmunds_iphone_battery_state` | Charging / Not Charging |
| `sensor.edmunds_iphone_activity` | Stationary / Walking / Unknown |
| `sensor.edmunds_iphone_last_update_trigger` | Launch / Siri / Manual / Background Fetch |

(Monica equivalents: replace `edmunds` with `monicas`)

## Troubleshooting

**Good Morning not firing:**
1. Check `input_boolean.edmund_awake` and `input_boolean.monica_awake` in Developer Tools → States
2. If one is still `off`, that person's signals haven't fired — check their phone sensors
3. Verify `input_select.house_mode` is "Night" (Good Morning only fires from Night mode)

**Good Morning fires too early (one person still sleeping):**
- Check which signal falsely triggered — bed presence bouncing is the usual suspect
- Consider removing the unreliable signal from that person's automation

**8Sleep alarm not syncing:**
- Check `sensor.edmunds_iphone_next_alarm` has a value within 24 hours
- Verify the eight_sleep integration is connected in Settings → Integrations
