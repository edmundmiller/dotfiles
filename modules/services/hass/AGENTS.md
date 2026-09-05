# Home Assistant

Native NixOS `services.home-assistant`, not an OCI container. `default.nix`
owns infrastructure, core config, and custom components; explicitly imported
`_domains/` owns declarative automations/scenes/scripts. UI resources are separate
`!include` files. `devices.yaml` owns device/area assignments, applied by
`apply-devices.py` through WebSocket after HA starts.

- Runtime is `/var/lib/hass` as user `hass`; PostgreSQL recorder is optional.
  HTTP uses loopback `::1` with forwarded headers; firewall exposure is tailnet-only.
- Credentials are runtime-only. Use the `hass-config-flow` skill for API access;
  avoid tokens in SSH command arguments or printed state.
- Native HA backup integration is intentionally disabled: nightly restic covers
  `/var/lib/hass`; see [README.md](README.md). Removing that config is not a fix.
- `.storage` is HA's state database, not an editing interface. Use supported APIs
  for live state and config-entry operations; Nix remains declarative source.
- ZHA uses ZBT-2; sleepy devices need a mesh router before pairing. See
  [Zigbee mesh](docs/zigbee-mesh.md).

For domain work, use [_domains guidance](_domains/AGENTS.md) and the
`home-assistant-best-practices` / `hass-declarative` skills. Architecture research
has a [targeted guide](docs/public-config-patterns.md); it is not required for
routine edits. Custom-component pins/hashes are in `default.nix`.

NUC `hass-cli -o json` supports filtered entity/device/area reads. `hass-cli info`
uses a deprecated endpoint; do not treat that failure as an HA outage.
