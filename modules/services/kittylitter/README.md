# kittylitter

Service module for the patched `pkgs.my.kittylitter` Alleycat bridge daemon.

The managed `host.toml` now includes Hermes and can enable agents per host. By default it leaves all known bridges enabled, matching upstream's "use it if installed" behavior. To reduce picker noise on a specific host, override `enabledAgents`:

```nix
modules.services.kittylitter = {
  enable = true;
  enabledAgents = [ "pi" "hermes" "claude" ];
};
```

Enable it on a host with:

```nix
modules.services.kittylitter.enable = true;
```

Deploy before testing connectivity:

```sh
hey nuc # NixOS NUC
hey re  # MacTraitor-Pro / nix-darwin
```

Useful checks:

```sh
ssh nuc 'systemctl --user status kittylitter --no-pager'
ssh nuc 'kittylitter probe --timeout-secs 15'
ssh nuc 'kittylitter pair --qr'

launchctl print gui/$(id -u)/org.nixos.kittylitter
/run/current-system/sw/bin/kittylitter probe --timeout-secs 15
/run/current-system/sw/bin/kittylitter pair --qr
```

If the mobile/client app cannot connect after a refactor, first verify the target host was redeployed and the daemon is active, then re-pair that host.
