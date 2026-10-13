---
name: verify
description: Verify dotfiles changes at runtime without switching the system.
---

# Verify dotfiles changes

Don't `darwin-rebuild switch` to verify. Evaluate the generated value for this
host, then drive the consuming tool against it in a scratch dir.

- Hosts: `nix eval --raw .#darwinConfigurations --apply 'c: builtins.concatStringsSep " " (builtins.attrNames c)'`
  (this machine's hostname is one of them).
- Generated config files:
  `nix eval --raw '.#darwinConfigurations.<host>.config.home-manager.users.edmundmiller.xdg.configFile."<path>".text'`
- The live file under `~/.config` is the pre-change baseline until a rebuild.

## npm config (`modules/dev/node.nix`)

- Use npm >= 11.16 (the nix nodejs or `/opt/homebrew/bin/npm`); the shell's
  default npm 11.6 warns `Unknown user config "min-release-age"` and ignores it.
- Drive: `NPM_CONFIG_USERCONFIG=<evaluated file> npm install --prefix <tmp> --ignore-scripts <pkg>@<ver>`.
  ETARGET "with a date before …" means the release-age cooldown rejected it.
- `npm view` ignores `min-release-age`; use `npm install` to observe the cooldown.
- Bash here is GNU coreutils: `sed -i` with no `''`, `date -d '1 day ago'`.
