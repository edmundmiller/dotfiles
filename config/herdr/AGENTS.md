# Herdr configuration

Read `modules.shell.herdr.backend` before changing behavior. Both platforms
default to `native`; `native.app.enable` selects app configuration and defaults
to Darwin only. Servers use core only. `legacy` is a different protocol.

Native sources live in `native/`. The official installer owns the signed
`herdr-app` bundle and `hc`; Nix owns preferences, personal mods and the
`herdr-dev` helper. Read the running app's `~/.config/herdr-app/AGENTS.md` and
generated typings before changing mods. Run `herdr-app check <mod-folder>`
after every mod edit.

Activation deep-merges managed settings, keys and programs into writable JSON.
Preserve unowned preferences, shipped layouts/mods, generated instructions,
typings, layout click state and runtime documents. App commands own space/tab
structure. Never copy the old Workspace Manager YAML into native layout JSON.
The native helper opens existing checkouts with an agent and Hunk; it does not
create or remove jj workspaces. Preserve clean-workspace, closed-PR and typed
abandonment guards when porting that lifecycle.

Legacy `config.toml` and `workspace-manager.yml` remain for the TUI backend.
Use its terminal theme, explicit prefix bindings, packaged plugin hooks and
`herdr server reload-config` only in that backend. Native bindings use app
commands and leave Ctrl+C with the terminal. Remote shell helpers route by
`HERDR_BACKEND`.

Run `hey check config/herdr modules/shell/herdr` plus focused native behavior
tests. Activation, live app commands and runtime restarts require authority.
See `README.md` for native usage and legacy-only capabilities.
