# HA Domains

Each file is a logical grouping of HA config (scenes, automations, scripts, input helpers). Imported explicitly from `../default.nix`. Use `lib.mkAfter` for automations/scenes to append to base lists.

## Scene vs Automation vs Script

Pick the simplest primitive that fits:

| Primitive      | What it does                                                                 | When to use                                             |
| -------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------- |
| **Scene**      | Sets entity states. No logic, no service calls. Idempotent — safe to repeat. | Desired end-states (bedtime, morning, away, etc.)       |
| **Script**     | Sequence of actions with optional logic. Can call any service.               | Reusable multi-step procedures (everything_off, nudges) |
| **Automation** | Listens for triggers, runs actions with optional conditions.                 | Reactive behavior (presence, time, sensor changes)      |

**Design pattern:** Scenes define _what_ the state should be. Automations define _when_ to apply it. Scripts define _how_ to do complex procedures. Automations should `scene.turn_on` wherever possible — keeps entity state centralized in scenes, automations stay thin trigger→scene wrappers.

Scenes are idempotent — every stage should assert the full expected state for that stage, even if a prior stage already set it. This makes each scene a reliable safety net regardless of entry path.

Ref: [Scenes vs Automations](https://community.home-assistant.io/t/scenes-vs-automations/288105), [Automations and Scenes and Scripts, Oh My!](https://community.home-assistant.io/t/automations-and-scenes-and-scripts-oh-my/583417)

### Intentionally not scene-ified

These automations have inline actions by design — do not refactor them into scenes:

| Automation                                           | Why inline is correct                                                                                                           |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `entrance_occupancy_night_light` (ambient.nix)       | Dynamic wait-loop (`wait_for_trigger`); scenes are static snapshots                                                             |
| `plant_glow_light_on/off` (ambient.nix)              | Single entity toggled on a time schedule; no state to compose                                                                   |
| `al_sleep_mode_on/off` (lighting.nix)                | Single switch, time-only triggers (pre-warmup + hard cutoff); scene path already handled by Winding Down / Good Morning scenes  |
| `Mid-morning` / `Sundown` scenes                     | AL sleep mode not included — it's always off by those times of day (7 AM hard cutoff)                                           |
| `Leave Home` scene                                   | AL sleep mode not included — irrelevant when nobody is home                                                                     |
| `Vacation` scene                                     | AL sleep mode not included — long-term away state, not a sleep cycle                                                            |
| 8Sleep / focus / wake detection automations (sleep/) | Arbitrary service calls (`eight_sleep.*`, `alarm_dismiss`, `side_off`) with per-person conditions; can't be expressed as scenes |
| `bedtime_nudge` script (sleep/)                      | One-shot notification; no entity state to capture                                                                               |
| `dnd_on` automation (modes.nix)                      | Sends a notification; no entity state change worth a scene                                                                      |

## Files

- `ambient.nix` — Sun-based scenes (mid-morning, sundown), presence (arrive/leave), entrance occupancy night light
- `aranet.nix` — Aranet4 CO2 sensor: elevated/poor/cleared push notifications (thresholds: 1000/1500 ppm). Update `prefix` var to match device entity ID.
- `conversation.nix` — Voice/conversation config
- `lighting.nix` — Adaptive Lighting (circadian color temp + brightness)
- `modes.nix` — House modes (`Home`/`Away`/`Night`), goodnight toggle, DND, everything_off script
- `sleep/` — Three-stage bedtime (Winding Down → In Bed → Sleep), wake detection state machine, Apple↔8Sleep sync. See `sleep/AGENTS.md`
- `vacation.nix` — Vacation mode: 8Sleep away_mode, Ecobee away preset, lights/blinds/TV off; presence-triggered return
- `tv.nix` — TV/media inputs, scripts, automations (sleep timer, idle auto-off)

## Cross-domain dependencies

```
modes.nix (input_boolean.goodnight, input_select.house_mode)
  ├── ambient.nix reads house_mode for presence scene conditions
  ├── sleep/ sets goodnight=on / house_mode=Night at 10PM
  └── lighting.nix AL sleep mode: time-based triggers; scenes handle the goodnight path
```

## Lights

| Entity ID                              | Friendly Name       | Area        | Color Temp |
| -------------------------------------- | ------------------- | ----------- | ---------- |
| `light.essentials_a19_a60`             | Trashcan            | Kitchen     | ✅         |
| `light.essentials_a19_a60_2`           | Dishwasher          | Kitchen     | ✅         |
| `light.essentials_a19_a60_3`           | Bathroom Nightstand | Bedroom     | ✅         |
| `light.essentials_a19_a60_4`           | Window Nightstand   | Bedroom     | ✅         |
| `light.nanoleaf_multicolor_floor_lamp` | Couch Lamp          | Living Room | ✅         |
| `light.nanoleaf_multicolor_hd_ls`      | Edmund Desk         | Office      | ✅         |
| `light.smart_night_light_w`            | Night Light         | Entrance    | ✅         |

## Switches

| Entity ID                     | Friendly Name      | Area        | Notes                                  |
| ----------------------------- | ------------------ | ----------- | -------------------------------------- |
| `switch.eve_energy_20ebu4101` | Whitenoise Machine | Bedroom     | Controlled by sleep scenes             |
| `switch.plant_glow_light`     | Plant Glow Light   | Living Room | Onvis S4 Matter plug; on 8am–9pm daily |

## People & devices

| Entity ID                            | Notes                                     |
| ------------------------------------ | ----------------------------------------- |
| `person.edmund_miller`               | Edmund — presence tracking                |
| `person.moni`                        | Monica — presence tracking                |
| `binary_sensor.edmunds_iphone_focus` | Any focus active (Sleep, DND, Work, etc.) |
| `binary_sensor.monicas_iphone_focus` | Any focus active (Sleep, DND, Work, etc.) |
| `notify.mobile_app_edmunds_iphone`   | Push notifications → Edmund               |
| `notify.mobile_app_monicas_iphone`   | Push notifications → Monica               |

## Adaptive Lighting

Configured in `lighting.nix`. One "Living Space" switch covers all color-temp lights.

- Color temp: 2000K (warm) → 5500K (cool daylight)
- Brightness: 20% min → 100% max
- Sleep mode: 10% brightness, 1000K (deep warm red, melatonin-friendly)
- `take_over_control: true` — manual adjustments pause AL for that light
- Sleep mode schedule: **on at 9:30 PM** (pre-warmup), **off at 7:00 AM** (hard cutoff) — time-based automations in `lighting.nix`
- Sleep mode also embedded in scenes: Winding Down/In Bed/Sleep → on, Good Morning → off

### HA entities

- `switch.adaptive_lighting_living_space` — main toggle
- `switch.adaptive_lighting_sleep_mode_living_space` — sleep mode
- `switch.adaptive_lighting_adapt_brightness_living_space`
- `switch.adaptive_lighting_adapt_color_living_space`

### Splitting into multiple switches

Add another entry to the `adaptive_lighting` list. Each entry creates its own `switch.adaptive_lighting_*` entities. Useful if office should have different brightness/color curves than living room.

## Adding a new domain

1. Create `_domains/<name>.nix` (simple) or `_domains/<name>/default.nix` (complex)
2. Add import to `../default.nix` imports list
3. Use `lib.mkAfter` for `automation`, `scene`, `script` to append (not override)
4. DRY with let-bindings for repeated action sets (see `vacationStart`/`vacationEnd` in `vacation.nix`)

**Use a directory** when the domain has non-obvious logic, troubleshooting steps, or entity references worth documenting (see `sleep/` for reference).
