---
purpose: Describe Tailscale ownership, Rex remote access, and the reference agent architecture.
applies_to: Tailscale module, host tunnel, tailnet services, or Rex phone setup.
entrypoint: Read this doc, then modules/services/tailscale.nix.
verification: On Darwin, build darwin-tailscaled-owner-assertions and check tailscaled is connected with SSH enabled. On NixOS, check tailscaled is active.
update_when: Tunnel ownership, Rex endpoints, ACLs, or Tailscale service wiring changes.
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
- Darwin: Nix-managed open-source `tailscaled`, CLI, and MagicDNS resolver. This variant is required for hosting Tailscale SSH. Do not install a GUI Tailscale variant or the Homebrew `tailscale` formula alongside it; only one daemon can own the tunnel. Login and `tailscale set --ssh` remain one-time stateful commands outside Nix.

After the first rebuild or after logging out, authenticate and enable Tailscale SSH:

```bash
sudo tailscale up --ssh --accept-routes
```

The tailnet policy must also authorize the source identity, destination device, and local macOS user in its `ssh` section.

## Rex remote access and the current setup

Rex provides remote terminal sessions without Tailscale SSH. Its embedded
Tailscale node exposes Rex, not the whole machine's network. System-wide
Tailscale still connects browsers and other applications to tailnet services.
The macOS GUI app can provide that network connection alongside Rex. Hosting
Tailscale SSH instead requires the open-source `tailscaled` variant.

Verified on 2026-10-29:

| Host           | Rex address                                          | Access                                                                  |
| -------------- | ---------------------------------------------------- | ----------------------------------------------------------------------- |
| NUC            | `https://nuc-rex.cinnamon-rooster.ts.net`            | Runs as `emiller`; only the Tailscale identity's owner is allowed       |
| MacTraitor Pro | `https://mactraitor-pro-rex.cinnamon-rooster.ts.net` | Embedded Tailscale node running with HTTPS available; owner-only access |

The Mac successfully authenticated to the NUC's Rex API at that address as
`emiller`. This verifies the server connection, not an iPhone connection.
The NUC's Rex node is separate from its system-wide Tailscale identity at
`100.112.179.64`. Its declaration lives in `hosts/nuc/default.nix`; the Mac's
host entry and setup instructions live in [the Rex configuration](../config/rex/README.md#nuc-connection).

The laptop still uses Nix-managed `tailscaled`. Direct inspection through
`/var/run/tailscaled.socket` found it online at `100.117.59.64`, with SSH enabled,
no health warnings, and a successful ping to the NUC. However, the old GUI
network extension was also active. Plain `tailscale status` reached that
logged-out extension instead of the healthy Nix daemon.

The September migration uninstalled the Homebrew app but did not successfully
deactivate its network extension. Rebuilds do not remove these leftovers because
Homebrew activation has `cleanup = "none"`. For diagnosis, select the Nix daemon
explicitly:

```sh
tailscale --socket=/var/run/tailscaled.socket status
```

Using the GUI app for system-wide networking and Rex for remote terminals was
discussed as an alternative. That switch has not been applied. The current Nix
configuration still owns `tailscaled`; do not treat the GUI app as the intended
owner until an authorized migration changes that configuration and verifies
connectivity. Keep Tailscale SSH if independent SSH access is still wanted.

## Reference: Jess Frazelle's Rex-based agent

In her [2026-10-29 post](https://x.com/jessfraz/status/2115791403624378474),
Jess Frazelle describes a personal agent that finds existing conversations and
proposes action items rather than only summarizing email. The linked
[jessfraz/agent repository](https://github.com/jessfraz/agent) uses Pi Durable for
persistent conversations and Rex for hosts, sessions, and terminals. A main
coordinator reuses the relevant task; workers run on macOS or Linux, with one
named Rex session per task and terminals for its subagents. A phone can access
the CLI through Rex.

Its [setup documentation](https://github.com/jessfraz/agent/blob/main/docs/setup.md)
also requires native Tailscale for agent coordinator/worker communication,
separate from Rex's embedded identity. The agent listens on the native Tailscale
interface at port 43187 and checks peer identity. This architecture does not
require Tailscale SSH. Rex replaces the remote-terminal use case, not every
application's need for system-wide Tailscale. This is a reference architecture,
not a record that her agent has been installed here.

## Add the NUC in Rex on iOS

To add the NUC on your phone, connect the iPhone's Tailscale app to the same
tailnet under the owner's account, then paste this address into Rex's server
connection settings:

```text
https://nuc-rex.cinnamon-rooster.ts.net
```

## Tailnet Info

- Tailnet: `cinnamon-rooster.ts.net`
- NUC IP: `100.112.179.64`
- MagicDNS search domain configured in NixOS resolved

## References

- [Tailscale GitOps ACLs](https://tailscale.com/docs/gitops)
- [Tailscale Services](https://tailscale.com/docs/features/services)
- [ACL Grants](https://tailscale.com/kb/1324/acl-grants)
- [Tailscale Serve](https://tailscale.com/kb/1312/serve)
- [Tailscale SSH](https://tailscale.com/docs/features/tailscale-ssh)
- [Open-source tailscaled on macOS](https://github.com/tailscale/tailscale/wiki/Tailscaled-on-macOS)
