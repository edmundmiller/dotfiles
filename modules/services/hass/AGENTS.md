# Home Assistant Module

Native `services.home-assistant` NixOS module. NixOS-only (`isDarwin` guard).

## Structure

- `default.nix` — Module definition
- `README.md` — Human docs with migration guide and home-ops parity table

## Key Facts

- Uses native `services.home-assistant` (NOT OCI container)
- Config dir: `/var/lib/hass` (NixOS default), runs as `hass` user
- Declarative config: `default_config`, HTTP on `::1` with `use_x_forwarded_for`
- UI automations/scenes/scripts via `!include` + tmpfiles for empty yaml
- PostgreSQL recorder via `postgres.enable` (provisions db + psycopg2)
- Firewall only opens on `tailscale0` interface
- Host config: `hosts/nuc/default.nix` enables hass + postgres + homebridge + tailscale

## NixOS Wiki Reference

Before making changes, fetch the NixOS HA wiki for current best practices:

```bash
curl -s https://wiki.nixos.org/wiki/Home_Assistant | bunx mdream --origin https://wiki.nixos.org --preset minimal
```

Covers: native `services.home-assistant`, declarative config, component deps, USB passthrough, postgres recorder, nginx reverse proxy, custom components, Zigbee OTA.
