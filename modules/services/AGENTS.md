# NUC services

Wrap upstream NixOS modules under `modules.services.<name>` and enable them in
`hosts/nuc/default.nix`. Both `<name>.nix` and `<name>/default.nix` are discovered.
NixOS-only options need `optionalAttrs (!isDarwin)`. Credentials use agenix
paths, with ownership matching the consuming service user.

## Registry ownership

Each service declares its own `lib.my.mkRegistry` defaults for `gatus` and/or
`homepage`. Aggregators collect enabled services; add endpoints/cards in the
owner, not in Gatus/Homepage. Only resources without a module remain hard-coded
in aggregators. Hosts can override defaults.

Homepage groups must already exist or cards are silently dropped. Widget secrets
use `{{HOMEPAGE_VAR_*}}` backed by `homepage-env.age`. Gatus registry entries
opt into alert providers with `alerts = true`.

## Validation and deployment

Repository tests cover wrapper options, guards, registries, generated config,
and local integration, not daemon behavior already tested by nixpkgs. Prefer
the service's native parser for generated config; reserve `_tests/` VM checks
for runtime contracts and targeted Linux/NUC runs, not every routine CI run.

Build with `hey nuc-wt build`; deploy with `hey nuc` when authorized. A local
build or Mac activation does not update the NUC. Deployment completion includes
checking the changed service on the target host.

## Tailscale services

HTTPS for `svc:<name>` runs through the WireGuard overlay; do not open firewall
port 443. Keep backends loopback-only where supported, or restrict their port
to `tailscale0`. Existing proxy examples are in `agentsview/`, `opencode/`, and
`hass/`.

VIP service definitions and explicit ACL grants belong to
`~/src/personal/tailnet`, not manual admin-console approval. Tailnet changes
require separate authorization. Use that repo's current deployment workflow;
when updating a VIP service through the API, preserve its two existing `addrs`.
Successful device registration reports `approvalLevel: approved:auto` and
`configured: ready`. The dotfiles module owns the systemd `tailscale serve`
proxy, including startup retry and service-specific cleanup.
