# Home Assistant Module

Native `services.home-assistant` NixOS module. NixOS-only (`isDarwin` guard).

## Structure

- `default.nix` — Module definition (options, core HA config, infra/systemd, custom components)
- `_domains/` — Domain files (scenes, automations, scripts) — see `_domains/AGENTS.md`
- `devices.yaml` — Declarative device→area assignments (applied via WebSocket API)
- `apply-devices.py` — Script to apply devices.yaml (runs as systemd oneshot after HA starts)
- `blueprints/` — Custom automation blueprints
- `README.md` — Human docs with migration guide and home-ops parity table

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

## hass-cli (agent-friendly API wrapper)

`home-assistant-cli` is installed on the NUC. Configure via env vars then run over SSH:

```bash
# One-liner: get token + run command
TOKEN=$(ssh nuc "sudo python3 -c '...'")  # see hass-config-flow skill
ssh nuc "HASS_SERVER=http://localhost:8123 HASS_TOKEN=$TOKEN hass-cli state list"
```

Or set env vars in your SSH session:

```bash
ssh nuc
export HASS_SERVER=http://localhost:8123
export HASS_TOKEN=<token>
hass-cli state list
hass-cli state list 'light.*'
hass-cli device list
hass-cli area list
hass-cli service call homeassistant.toggle --arguments entity_id=light.office
hass-cli device assign Kitchen --match "Kitchen Light"
hass-cli event watch
```

Use `hass-cli --output yaml` or `-o json` for machine-readable output.
The `devices.yaml` → `apply-devices.py` pattern could be replaced with `hass-cli device assign` for one-off changes.

## NixOS Wiki Reference

Before making changes, fetch the NixOS HA wiki for current best practices:

```bash
curl -s https://wiki.nixos.org/wiki/Home_Assistant | bunx mdream --origin https://wiki.nixos.org --preset minimal
```

Covers: native `services.home-assistant`, declarative config, component deps, USB passthrough, postgres recorder, nginx reverse proxy, custom components, Zigbee OTA.
