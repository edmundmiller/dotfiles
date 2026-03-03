# Obsidian Sync Module

Headless Obsidian Sync via `obsidian-headless` CLI. Replaces the old LinuxServer Docker container.

## Key Facts

- **Cross-platform** — darwin gets `ob` CLI only; NixOS gets systemd service + CLI
- **Nix-packaged** — `pkgs.my.obsidian-headless` (see `packages/obsidian-headless/`)
- **Two modes**: `server` (pull-only, read-only copy) and `desktop` (bidirectional)
- **One-time setup required** — `ob login` + `ob sync-setup` before service starts
- **Do NOT combine** with Obsidian desktop app sync on the same device

## Sync Modes

Controlled by `ob sync-config --mode <mode>` (run as `ExecStartPre` on NixOS):

- **`bidirectional`** — full two-way sync. Default when `mode = "desktop"`.
- **`pull-only`** — download from remote only. Default when `mode = "server"`.
- **`mirror-remote`** — pull-only + revert any local changes back to remote state.

Set `syncMode` to override the default derived from `mode`.

## Services (NixOS only)

- `obsidian-sync` — long-running, `ob sync --continuous`
  - `ExecStartPre` runs `ob sync-config` to set mode/device before each start
  - Runs as configured user, sandboxed with `ProtectHome=read-only`

## Options

| Option       | Default            | Notes                                                   |
| ------------ | ------------------ | ------------------------------------------------------- |
| `mode`       | `server`           | `server` (pull-only) or `desktop` (bidirectional)       |
| `syncMode`   | derived from mode  | Override: `bidirectional`, `pull-only`, `mirror-remote` |
| `vaultPath`  | `~/obsidian-vault` | Directory synced to/from remote vault                   |
| `deviceName` | hostname           | Identifies this device in Obsidian Sync                 |
| `continuous` | `true`             | Watch for changes vs one-shot sync                      |

## Files

- `default.nix` — module definition
- `AGENTS.md` — this file

## Related

- `packages/obsidian-headless/` — Nix package (buildNpmPackage + vendored lockfile)
- `hosts/nuc/default.nix` — primary consumer (server mode)
- https://help.obsidian.md/sync/headless — upstream docs
