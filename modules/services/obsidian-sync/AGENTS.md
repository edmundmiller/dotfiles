---
purpose: Define NUC Headless Sync and corruption guard conventions.
applies_to: modules.services.obsidian-sync
entrypoint: default.nix
verification: nix build .#checks.aarch64-darwin.obsidian-sync-safety-assertions
update_when: Sync topology, options, exclusions, or guard behavior changes.
---

# Obsidian Sync Module

Headless Obsidian Sync for the NUC. Mac intentionally uses Desktop Sync.

## Key Facts

- **NixOS/headless focused** — Darwin hosts should use the GUI Obsidian app instead of this service
- **Nix-packaged** — `pkgs.my.obsidian-headless` (see `packages/obsidian-headless/`)
- **Two modes**: `server` (pull-only, read-only copy) and `desktop` (bidirectional)
- **One-time setup required** — `ob login` + `ob sync-setup` before service starts
- **Do NOT combine** with Obsidian desktop app sync on the same device
- **Shared policy** — vault `07_Metadata/Validation/obsidian-sync-policy.json`
- **Tripwire** — `ExecStartPre` plus 30-second timer; stops Headless without rewriting vault data

## Sync Modes

Controlled by `ob sync-config --mode <mode>` (run as `ExecStartPre` on NixOS):

- **`bidirectional`** — full two-way sync. Default when `mode = "desktop"`.
- **`pull-only`** — download from remote only. Default when `mode = "server"`.
- **`mirror-remote`** — pull-only + revert any local changes back to remote state.

Set `syncMode` to override the default derived from `mode`.

## Services

**NixOS** — `systemd.services.obsidian-sync`

- `ExecStartPre` runs `ob sync-config` to set mode/device before each start
- `ExecStartPre` rejects unsafe paths, missing exclusions, markers, loops, churn, and engine conflicts
- Runs as configured user, sandboxed with `ProtectHome=read-only`
- `obsidian-sync-guard.timer` stops the writer and fails Healthchecks.io on violations

**Darwin** — no Headless launchd service. The Mac host defines a Desktop safety guard.

## Options

| Option       | Default            | Notes                                                   |
| ------------ | ------------------ | ------------------------------------------------------- |
| `mode`       | `server`           | `server` (pull-only) or `desktop` (bidirectional)       |
| `syncMode`   | derived from mode  | Override: `bidirectional`, `pull-only`, `mirror-remote` |
| `vaultPath`  | `~/obsidian-vault` | Directory synced to/from remote vault                   |
| `deviceName` | hostname           | Identifies this device in Obsidian Sync                 |
| `continuous` | `true`             | Watch for changes vs one-shot sync                      |
| `safety.*`   | enabled            | Checker, policy, state, interval, and sync freshness    |

## Files

- `default.nix` — module definition
- `AGENTS.md` — this file

## Related

- `packages/obsidian-headless/` — Nix package (buildNpmPackage + vendored lockfile)
- `hosts/nuc/default.nix` — primary consumer (server mode)
- https://obsidian.md/help/sync/headless — upstream docs
