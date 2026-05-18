# kittylitter service module

This module manages the patched `pkgs.my.kittylitter` daemon for remote Alleycat/kittylitter pairing.

## Host enablement

Enable per host with:

```nix
modules.services.kittylitter.enable = true;
```

Current users:

- `hosts/nuc/default.nix` — NixOS/Home Manager user systemd service.
- `hosts/mactraitorpro/default.nix` — nix-darwin user launchd agent.

## Important deployment note

After changing this module, deploy the target host. The client may appear unable to connect until the host has received the module/service update.

NUC:

```sh
hey nuc
ssh nuc 'systemctl --user status kittylitter --no-pager'
ssh nuc 'kittylitter probe --timeout-secs 15'
ssh nuc 'kittylitter probe --agent pi --method thread/list --timeout-secs 20'
```

MacTraitor-Pro:

```sh
hey re
launchctl print gui/$(id -u)/org.nixos.kittylitter
/run/current-system/sw/bin/kittylitter probe --timeout-secs 15
```

## Pairing

If a client still does not reconnect after the service is healthy, re-pair the specific host:

```sh
ssh nuc 'kittylitter pair --qr'
```

On macOS:

```sh
/run/current-system/sw/bin/kittylitter pair --qr
```

## Behavior

The module preserves existing `host.toml` tokens while converging managed agent sections to `modules.services.kittylitter.enabledAgents`. Default is all known bridges (`codex`, `pi`, `hermes`, `amp`, `opencode`, `claude`, `droid`, `devin`, `grok`); hosts can narrow this list to keep the client picker focused. It also removes older manually-installed `npx kittylitter`/`com.sigkitten.kittylitter` service definitions so the managed Nix service owns the daemon.
