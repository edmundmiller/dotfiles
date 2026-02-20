# HA Domains

Each file is a logical grouping of HA config (scenes, automations, scripts, input helpers). Imported explicitly from `../default.nix`. Use `lib.mkAfter` for automations/scenes to append to base lists.

## Files

- `ambient.nix` — Sun-based scenes (mid-morning, sundown), presence (arrive/leave), entrance occupancy night light
- `conversation.nix` — Voice/conversation config
- `lighting.nix` — Adaptive Lighting (circadian color temp + brightness)
- `modes.nix` — House modes (`Home`/`Away`/`Night`), goodnight toggle, DND, everything_off script
- `sleep.nix` — Three-stage bedtime (Winding Down → In Bed → Sleep), bed presence, wake routines
- `tv.nix` — TV/media inputs, scripts, automations (sleep timer, idle auto-off)

## Cross-domain dependencies

```
modes.nix (input_boolean.goodnight, input_select.house_mode)
  ├── ambient.nix reads house_mode for presence scenes
  ├── sleep.nix sets goodnight=on at 10PM, house_mode=Night
  └── lighting.nix syncs AL sleep mode with goodnight toggle
```

## Lights

| Entity ID                              | Friendly Name | Area        | Color Temp |
| -------------------------------------- | ------------- | ----------- | ---------- |
| `light.essentials_a19_a60`             | Trashcan      | Kitchen     | ✅         |
| `light.essentials_a19_a60_2`           | Dishwasher    | Kitchen     | ✅         |
| `light.nanoleaf_multicolor_floor_lamp` | Couch Lamp    | Living Room | ✅         |
| `light.nanoleaf_multicolor_hd_ls`      | Edmund Desk   | Office      | ✅         |
| `light.smart_night_light_w`            | Night Light   | Entrance    | ✅         |

## Adaptive Lighting

Configured in `lighting.nix`. One "Living Space" switch covers all lights above.

- Color temp: 2000K (warm) → 5500K (cool daylight)
- Brightness: 20% min → 100% max
- Sleep mode: 5% brightness, 2000K
- `take_over_control: true` — manual adjustments pause AL for that light
- Sleep mode driven by `input_boolean.goodnight` (defined in `modes.nix`)

### HA entities

- `switch.adaptive_lighting_living_space` — main toggle
- `switch.adaptive_lighting_sleep_mode_living_space` — sleep mode
- `switch.adaptive_lighting_adapt_brightness_living_space`
- `switch.adaptive_lighting_adapt_color_living_space`

### Splitting into multiple switches

Add another entry to the `adaptive_lighting` list. Each entry creates its own `switch.adaptive_lighting_*` entities. Useful if office should have different brightness/color curves than living room.

## Adding a new domain

1. Create `_domains/<name>.nix`
2. Add import to `../default.nix` imports list
3. Use `lib.mkAfter` for `automation`, `scene`, `script` to append (not override)
4. DRY with let-bindings for repeated actions (see `setMode`/`tvOff` in `modes.nix`)
