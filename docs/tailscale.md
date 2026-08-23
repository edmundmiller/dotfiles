---
purpose: Describe Tailscale ownership, ACLs, and Darwin vs NixOS wiring.
applies_to: Tailscale module, host tunnel, or tailnet service changes.
entrypoint: Read this doc, then modules/services/tailscale.nix.
verification: On Darwin, build darwin-tailscale-app-owner-assertions and check Tailscale.app is Connected with a 100.x address. On NixOS, check tailscaled is active.
update_when: Tunnel ownership, Homebrew cask, ACLs, or Tailscale service wiring changes.
---

# Tailscale

## ACL Policy (GitOps)

ACLs are managed via **https://github.com/edmundmiller/tailnet** — not the Tailscale admin console directly.

```bash
# Clone, edit, push — GitHub Action syncs to Tailscale
cd /tmp && git clone git@github.com:edmundmiller/tailnet.git
vim tailnet/policy.hujson
cd tailnet && git commit -am "update ACL" && git push
```

The repo has a GitHub Action (`.github/workflows/tailscale.yml`) that:

- **On push to main:** applies the ACL via `tailscale/gitops-acl-action`
- **On PR:** tests the ACL without applying

Requires `TS_API_KEY` and `TS_TAILNET` secrets in the repo settings.
Generate API keys at https://login.tailscale.com/admin/settings/keys

## Tailscale Services (`svc:`)

NUC exposes services via `tailscale serve --service=svc:<name>`:

| Service        | URL                                              | Module                   |
| -------------- | ------------------------------------------------ | ------------------------ |
| Home Assistant | `https://homeassistant.cinnamon-rooster.ts.net/` | `modules/services/hass/` |
| Homebridge     | `https://homebridge.cinnamon-rooster.ts.net/`    | `modules/services/hass/` |
| OpenCode       | `https://opencode.cinnamon-rooster.ts.net/`      | (manual)                 |

Services need **two things** to work:

1. **Nix systemd service** — runs `tailscale serve --bg --service=svc:<name> --https=443 http://localhost:<port>`
2. **ACL grant** — in `policy.hujson`, services need an explicit grant:
   ```hujson
   {
     "src": ["autogroup:member"],
     "dst": ["svc:homeassistant", "svc:homebridge", "svc:opencode"],
     "ip":  ["*"],
   }
   ```

Without the ACL grant, you get "Advertising the service, but some required ports are missing".

## Module: `modules/services/tailscale.nix`

Enables Tailscale with:

- Shell aliases (`tsc`, `tsu`, `tsd`, `tss`)
- NixOS: `tailscaled`, open firewall, operator mode (no sudo for `tailscale serve`), MagicDNS via resolved
- Darwin: Homebrew `tailscale-app` plus MagicDNS resolver. Do **not** start Nix `tailscaled`, install `pkgs.tailscale`, or add the Homebrew `tailscale` formula or CLI-only cask; the official `Tailscale.app` Network Extension owns the tunnel. A second daemon leaves the GUI stuck Connecting and `/usr/local/bin/tailscale` returning `Tailscale.CLIError error 1`. Login and Network Extension approval stay out of Nix.

## Tailnet Info

- Tailnet: `cinnamon-rooster.ts.net`
- NUC IP: `100.112.179.64`
- MagicDNS search domain configured in NixOS resolved

## References

- [Tailscale GitOps ACLs](https://tailscale.com/docs/gitops)
- [Tailscale Services](https://tailscale.com/docs/features/services)
- [ACL Grants](https://tailscale.com/kb/1324/acl-grants)
- [Tailscale Serve](https://tailscale.com/kb/1312/serve)
