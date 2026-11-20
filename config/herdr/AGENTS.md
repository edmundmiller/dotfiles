# Herdr configuration

Native sources live in `native/`. The official installer owns the signed `herdr-app` bundle and `hc`; Nix owns managed preferences, personal mods and `herdr-dev`. `native.app.enable` defaults to Darwin only. Servers use core only. The legacy TUI, plugins and YAML layout are retired.

Read the running app's `~/.config/herdr-app/AGENTS.md` and generated typings before changing mods. Run `herdr-app check <mod-folder>` after every mod edit.

Activation deep-merges managed leaves into writable JSON. Preserve unowned preferences, shipped layouts/mods, generated instructions, typings, layout click state and runtime documents. App commands own space/tab structure. Keep whole-directory mod links so relative imports resolve within their canonical directory.

The native helper opens existing checkouts with an agent and Hunk. It does not create or remove jj workspaces. Preserve checkouts, bookmarks and receipts; defer unsupported lifecycle operations rather than bypassing clean-workspace, closed-PR or typed-abandonment protections. `hnuc` and `herdr-studios` use `hc` only.

Run `hey check config/herdr modules/shell/herdr` plus focused native behavior tests. Activation, live app commands and runtime restarts require authority. See `README.md` for usage and recovery.
