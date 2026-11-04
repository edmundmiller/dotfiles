---
purpose: Route NUC deployment and recovery to the supported hey commands.
applies_to: Building, activating, or rolling back the NUC configuration.
entrypoint: Read docs/runbooks/deploy-nuc.md and bin/hey.d/remote.nu.
verification: Run hey nuc-wt build and inspect services after authorized activation.
update_when: NUC deployment transport, source isolation, or recovery changes.
---

# NUC deployment

The canonical procedure is [the NUC deployment runbook](../../docs/runbooks/deploy-nuc.md).
`bin/hey.d/remote.nu` owns the commands.

`hey nuc` runs `nixos-rebuild` locally when invoked on the NUC. From another
host it syncs the worktree to a unique `/tmp/dotfiles-worktree-*` directory,
then evaluates and builds on the NUC. Each invocation owns its snapshot;
active leases protect it, and pruning retains five recent snapshots.

```bash
hey nuc-wt build          # build without activation
hey nuc-wt                # dry-activate from the synced snapshot
hey nuc-wt test           # activate until reboot
hey nuc-wt switch         # activate and select the boot generation
hey nuc                  # deploy, choosing local or remote by hostname
```

Activation modes require a clean commit; dirty snapshots support only build
and VM checks. `test` and `switch` affect the live host and require deployment authorization.
Do not evaluate `nixosConfigurations.nuc` on macOS; use the remote build.

## Recovery and verification

This `nixos-rebuild` path does **not** provide deploy-rs magic rollback.
Keep console access available for networking changes. The separately exposed
`hey deploy HOST` command uses deploy-rs; it is not the implementation of `hey nuc`.

```bash
hey nuc-status
hey nuc-service hermes-agent
hey nuc-logs hermes-agent 100
hey nuc-generations
hey nuc-rollback          # changes the live host; authorize first
```

Private GitHub inputs use `nix-private-github` and the root-owned token file.
Never print the token. Automatic upgrades are separately configured in
`hosts/_server.nix`; they fetch the published GitHub flake rather than this worktree.
