# Obsidian headless sync

NUC uses `pkgs.my.obsidian-headless`; Macs use Desktop Sync. Do not run both
engines on the same device. One-time `ob login` / `ob sync-setup` is required.

`mode = server` defaults to pull-only, `desktop` to bidirectional; `syncMode`
can override. `mirror-remote` also reverts local changes, so it is destructive.
`ExecStartPre` applies mode/device settings and rejects unsafe paths, missing
exclusions, markers, loops, churn, and engine conflicts.

The shared policy is `07_Metadata/Validation/obsidian-sync-policy.json` in the
vault. The startup guard and 30-second timer stop the writer and fail Healthchecks
on corruption; they do not rewrite vault data. A separate twice-daily Git dirt
audit permits changes only under `00_Inbox/`, without stopping sync.

NixOS runs as the configured user with `ProtectHome=read-only`. Darwin has a
Desktop safety guard, not a headless launchd service. Focused check:
`nix build .#checks.aarch64-darwin.obsidian-sync-safety-assertions` on Darwin.
