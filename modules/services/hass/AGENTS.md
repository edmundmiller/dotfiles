# Home Assistant Module

Native `services.home-assistant` NixOS module. NixOS-only (`isDarwin` guard).

## Structure

- `default.nix` — Module definition (options, core HA config, infra/systemd, custom components)
- `_domains/ambient.nix` — Sun-based scenes (mid-morning, sundown), presence (arrive/leave), occupancy (entrance night light)
- `_domains/lighting.nix` — Adaptive Lighting config (circadian color temp + brightness)
- `_domains/modes.nix` — House modes (`Home`/`Away`/`Night`), goodnight/morning routines, DND, scenes
- `_domains/sleep.nix` — Three-stage bedtime (Winding Down → In Bed → Sleep), bed presence, wake routines
- `_domains/tv.nix` — TV/media inputs, scripts, automations (sleep timer, idle auto-off)
- `_domains/conversation.nix` — Voice/conversation config
- `devices.yaml` — Declarative device→area assignments (applied via WebSocket API)
- `apply-devices.py` — Script to apply devices.yaml (runs as systemd oneshot after HA starts)
- `blueprints/` — Custom automation blueprints
- `README.md` — Human docs with migration guide and home-ops parity table

### Adding new domains

Create `_domains/<name>.nix`. Set `services.home-assistant.config.*` and use `lib.mkAfter` for automations. The `_` prefix excludes from auto-discovery; `default.nix` imports explicitly.

Nix helper functions (let-bindings) DRY common actions — see `tvOff`/`setMode` patterns in existing domain files.

## Custom Components

Built via `pkgs.buildHomeAssistantComponent` in `default.nix`:

| Component         | Domain              | Version | Purpose                                    |
| ----------------- | ------------------- | ------- | ------------------------------------------ |
| adaptive-lighting | `adaptive_lighting` | 1.30.1  | Sun-synchronized color temp & brightness   |
| hacs              | `hacs`              | 2.0.5   | Home Assistant Community Store             |
| eight-sleep       | `eight_sleep`       | 1.0.22  | Smart mattress (bed presence, temperature) |

### Updating custom components

1. Find new version tag on GitHub
2. `nix-prefetch-url --unpack "https://github.com/<owner>/<repo>/archive/refs/tags/<tag>.tar.gz"`
3. Convert hash: `nix hash convert --hash-algo sha256 --to sri <hash>`
4. Update `version`, `tag`, and `hash` in `default.nix`

## Adaptive Lighting

Configured in `_domains/lighting.nix`. Provides circadian color temperature and brightness adjustment.

### How it works

- Automatically adjusts light color temp (2000K warm → 5500K cool) and brightness (20–100%) based on sun position
- Sleep mode (5% brightness, 2000K) syncs with `input_boolean.goodnight` via automations in lighting.nix
- Manual control detection: if a light is manually adjusted, AL stops adapting it until it cycles off/on

### HA entities created

- `switch.adaptive_lighting_living_space` — main on/off for adaptation
- `switch.adaptive_lighting_sleep_mode_living_space` — sleep mode toggle
- `switch.adaptive_lighting_adapt_brightness_living_space` — brightness adaptation toggle
- `switch.adaptive_lighting_adapt_color_living_space` — color adaptation toggle

### Lights managed

All color-temp-capable lights in one "Living Space" switch:

- `light.essentials_a19_a60` (Trashcan / kitchen)
- `light.essentials_a19_a60_2` (Dishwasher / kitchen)
- `light.nanoleaf_multicolor_floor_lamp` (Couch Lamp)
- `light.nanoleaf_multicolor_hd_ls` (Edmund Desk)
- `light.smart_night_light_w` (Entrance night light)

### Integration with sleep flow

The goodnight toggle (`input_boolean.goodnight`) drives AL sleep mode:

- `goodnight` on → `switch.adaptive_lighting_sleep_mode_living_space` on
- `goodnight` off → sleep mode off

This chains with the existing bedtime flow in `sleep.nix`:

1. Winding Down (10 PM) sets `goodnight = on` → AL enters sleep mode
2. Good Morning resets `goodnight = off` → AL resumes normal adaptation

### Adding lights or splitting switches

To create separate AL switches (e.g., office vs living room), add another entry to the `adaptive_lighting` list in `lighting.nix`. Each gets its own set of `switch.adaptive_lighting_*` entities.

## Key Facts

- Uses native `services.home-assistant` (NOT OCI container)
- Config dir: `/var/lib/hass` (NixOS default), runs as `hass` user
- Declarative config: `default_config`, HTTP on `::1` with `use_x_forwarded_for`
- Automations declared in Nix (domain files), not YAML — enables helper functions/variables
- UI automations/scenes/scripts via `!include` + tmpfiles for empty yaml
- Device→area assignments: `devices.yaml` applied by `hass-apply-devices.service` via WebSocket API
- Token: auto-generated JWT from `/var/lib/hass/.storage/auth` (client_name=`agent-automation`)
- PostgreSQL recorder via `postgres.enable` (provisions db + psycopg2)
- Firewall only opens on `tailscale0` interface
- Host config: `hosts/nuc/default.nix` enables hass + postgres + homebridge + tailscale

## NixOS Wiki Reference

Before making changes, fetch the NixOS HA wiki for current best practices:

```bash
curl -s https://wiki.nixos.org/wiki/Home_Assistant | bunx mdream --origin https://wiki.nixos.org --preset minimal
```

Covers: native `services.home-assistant`, declarative config, component deps, USB passthrough, postgres recorder, nginx reverse proxy, custom components, Zigbee OTA.
