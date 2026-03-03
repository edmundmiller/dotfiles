# Obsidian Sync Module

Headless Obsidian Sync via `obsidian-headless` CLI. Replaces the old LinuxServer Docker container.

## Key Facts

- **NixOS-only** — uses systemd, not available on darwin
- **Nix-packaged** — `pkgs.my.obsidian-headless` (see `packages/obsidian-headless/`)
- **Two modes**: `server` (pull-only, read-only copy) and `desktop` (bidirectional)
- **One-time setup required** — `ob login` + `ob sync-setup` before service starts
- **Do NOT combine** with Obsidian desktop app sync on the same device

## Services

- `obsidian-sync` — long-running, `ob sync --continuous`
  - `ExecStartPre` sets sync mode via `ob sync-config`
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
