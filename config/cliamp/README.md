---
purpose: Explain the managed CLIamp configuration and Nightrider installation.
applies_to: Changes to CLIamp settings or its shell module.
entrypoint: Edit config/cliamp/config.toml or modules/shell/cliamp/default.nix.
verification: Rebuild, then run `cliamp plugins list`.
update_when: CLIamp config ownership, plugin pins, or activation behavior changes.
---

# CLIamp

`config.toml` is the initial template for `~/.config/cliamp/config.toml`.
CLIamp updates this file while it runs, so the module creates a writable copy
only when the live file does not exist.

The Nightrider source is not vendored here. `modules/shell/cliamp/default.nix`
fetches a pinned upstream revision, installs it into the live plugin directory,
and records its content hash in CLIamp's trust manifest.

When both CLIamp and Herdr are enabled, the Herdr module installs
`coryshaw1/herdr-cliamp`. The tracked Herdr config enables nested sessions for
the persistent floating player.
