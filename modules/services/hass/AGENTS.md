# Home Assistant Module

NixOS OCI container module for Home Assistant. NixOS-only (`isDarwin` guard).

## Structure

- `default.nix` — Module definition
- `README.md` — Human docs with home-ops parity table

## Key Facts

- Container runs `--network=host --privileged` (needs host networking for device discovery)
- Config lives at `configDir` (default `~/HomeAssistant`), mounted as `/config`
- Optional postgres, code-server sidecar, homebridge, tailscale service proxies
- Firewall only opens on `tailscale0` interface
- Patterns pulled from [home-ops k8s](https://github.com/edmundmiller/home-ops/tree/main/kubernetes/apps/default/home-assistant/app)
- Host config in `hosts/nuc/default.nix` enables hass + homebridge + tailscale services

## NixOS Wiki Reference

Before making changes, fetch the NixOS HA wiki for current best practices:

```bash
curl -s https://wiki.nixos.org/wiki/Home_Assistant | bunx mdream --origin https://wiki.nixos.org --preset minimal
```

Covers: native `services.home-assistant`, declarative `configuration.yaml` via nix, component/integration deps, Z-Wave/Zigbee USB passthrough, postgres recorder, nginx reverse proxy.
