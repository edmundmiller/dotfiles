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
