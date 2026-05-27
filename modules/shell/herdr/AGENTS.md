# Herdr Shell Module

This directory owns the `modules.shell.herdr` Nix module.

## Scope

- Configure the Herdr CLI/package, launcher, and optional tmux popup integration.
- Manage Herdr-specific Home Manager files such as the Pi theme and writable Herdr config bootstrap.
- Keep Pi package wiring in `modules/agents/pi/`; this module only exposes Herdr state/options such as `piThemeName`.

## Important Behavior

- Herdr's `config.toml` is intentionally bootstrapped as a writable file under `~/.config/herdr/config.toml` because Herdr updates onboarding/settings at runtime.
- Keep the bootstrap activation idempotent: it should update managed keys/commands without clobbering unrelated user-managed settings.
- `cfg.configFile` points at the template source; do not directly symlink it to the Herdr runtime config unless Herdr stops mutating that file.
- The `piThemeName` option is read-only and consumed by `modules/agents/pi` to select the matching Pi theme when Herdr is enabled.
- `tmux/open-herdr.sh` is the Herdr launcher, not a tmux launcher. Do not add a fallback to any other workspace owner here: when Ghostty starts Herdr, falling back to jmux/tmux can create the bad `Ghostty -> Herdr helper -> tmux -> Herdr` nesting loop. If Herdr is unavailable, fail visibly or drop to a plain login shell.

## Integration Points

- `modules.shell.tmux.rcFiles` sources the generated `tmux/herdr.conf` only when tmux is enabled. This is optional popup integration; it must not make tmux own Ghostty startup while Herdr or another higher-priority workspace owner is enabled.
- `modules.agents.pi` conditionally installs `npm:@ogulcancelik/pi-herdr` when `modules.shell.herdr.enable` is true.
- When Herdr is enabled, this module automatically installs Herdr integrations for enabled agent modules (`pi`, `claude`, `codex`, `opencode`, and local `hermes`) during Home Manager activation.
- On NixOS, this module also installs Herdr's Hermes Agent integration into every declared `services.hermes-agent.profiles` profile during system activation when `services.hermes-agent` is enabled.
- `config/herdr/config.toml` is the default template configured by this module.

## Editing Guidelines

- Use `mkIf cfg.enable` for runtime config.
- Preserve cross-platform assumptions unless adding explicit platform guards.
- Run `nixfmt` on changed Nix files.
