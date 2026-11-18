---
purpose: Migrate the two Macs to Determinate without losing settings or upstream recovery.
applies_to: Authorized MacTraitor-Pro and Seqeratop installation, activation, and recovery.
entrypoint: Prepare and validate the exact candidate before running the signed macOS installer.
verification: Check the running daemon, configuration ownership, effective settings, and a daemon build.
update_when: Determinate installation, runtime paths, maintenance ownership, or recovery changes.
---

# Determinate on Darwin

The Determinate installer and Nixd own the runtime and `/etc/nix/nix.conf`.
`determinateNix` owns `nix.custom.conf`, the registry, and Nixd configuration.
Importing its module does not install the runtime. The locked module version
does not pin the installed daemon, and `hey rollback` alone does not roll it back.
NixOS and the one-core Orb setup retain their existing Nix ownership.

Both Macs retain `cores = 2`, `max-jobs = 6`, all four additional caches and
their keys, and access restricted to root and the host's primary user. Registry
entries and legacy Nix search paths remain available. The existing Sunday 02:00
GC job retains `--delete-older-than 7d`; optimisation remains Sunday 04:15.
These launchd jobs use the installer-managed tools. Nixd's disk-pressure GC is
disabled so it does not compete with that retention policy. Do not run GC during
migration or remove recovery roots until both hosts have been accepted.

## Before changing the runtime

Migrate MacTraitor-Pro first. Seqeratop must wait for its verified acceptance.
Use an isolated checkout from current `origin/main`; preserve existing checkouts,
worktrees, receipts, and store-backed reporting tools. Coordinate with other
local Nix users before interrupting the daemon.

Confirm identity with `hostname`, `scutil --get LocalHostName`, `uname -a`, and
`id -un`. MacTraitor-Pro uses `emiller`; Seqeratop is `L19W56QXR4` and uses
`edmundmiller`. Do not infer the username from the inspecting machine.

In a private recovery directory outside the candidate source, record:

- The exact old system store path, upstream Nix store path, and system profile
  generation. Root the old system with `nix-store --realise OLD_SYSTEM
--add-root RECOVERY/upstream-system --indirect`.
- An independent profile using `nix-env --profile RECOVERY/upstream-profile
--set OLD_NIX`. Test its `bin/nix --version`, `store info --store daemon`, and
  `--store dummy:// eval --expr 'builtins.add 19 23'`, which must return 42
  without contacting the daemon. This profile must not resolve through
  `/run/current-system` or the global default profile.
- The existing `org.nixos.nix-daemon.plist`, its ownership/mode, and a dereferenced
  copy of `nix.conf`. Inspect configuration locally for secrets; never publish
  the complete file. Validate the saved plist with `plutil -lint`.
- The selected paths of `gh`, Python, Git, and SSH. Retain their system/user
  closure roots so an installer failure cannot remove the tools needed to report.

This tests the fallback CLI and saves the known-running daemon definition. It
does not prove a post-migration daemon rollback. macOS cannot build through a
diverted user-owned store, so an isolated-store build is not a substitute.

After other local Nix work stops, rehearse restoring the saved plist with
administrator authentication. Install it as root:wheel, mode 0644, boot out
`system/org.nixos.nix-daemon`, and bootstrap the saved definition. Require the
rooted upstream executable in `ps` and a fresh build/read through the independent
profile. Save the evidence separately from any post-migration rollback claim.
Before installation, take a consistent SQLite `.backup` of
`/nix/var/nix/db/db.sqlite` and save its adjacent `schema` file in the private
recovery directory. Never publish that database.

Run `hey check` and `hey check --platform darwin` for the exact candidate.
Use a supervised PTY for `hey re build`. Inspect the resulting activation and
service changes before switching. These checks do not activate either host.
Publication follows [candidate CI](candidate-ci.md), with the exact passing SHA.
No NUC deployment belongs to this migration.

## Install and activate

Use the [official macOS migration package](https://docs.determinate.systems/guides/migrating-from-upstream-nix/).
The package migrates the existing store and profiles in place. Do not uninstall
Nix, delete its volume, or use the Linux receipt-removal procedure on macOS.
Download and retain the package, record its SHA-256, and verify it with
`pkgutil --check-signature`. Require the notarized Determinate Systems installer
certificate, team `X3JQ4VPJZ6`. Record its version separately from the module lock.

Stage the validated system's disabled-GC configuration **before** starting the
installer. Nixd otherwise starts its default automatic GC immediately, before
the first Darwin activation can disable it. MacTraitor-Pro exposed this ordering
hazard during migration. Do not rely on activating quickly enough afterward.

For an upstream-only host with no existing Determinate configuration:

```sh
built_system=$(realpath result)
jq -e '.garbageCollector.strategy == "disabled"' "$built_system/etc/determinate/config.json"
test ! -e /etc/determinate/config.json && test ! -L /etc/determinate/config.json &&
  sudo install -d -m 0755 /etc/determinate &&
  sudo ln -s "$built_system/etc/determinate/config.json" /etc/determinate/config.json
```

Keep `result` rooted. The staged symlink uses the generated file from the exact
built candidate; do not hand-edit its contents. Activation replaces it with the
normal `/etc/static` link. If configuration already exists, inspect its ownership
and reconcile it before installation rather than overwriting it blindly.

The package needs administrator authentication. Use a supervised terminal for
`sudo /usr/sbin/installer -pkg PACKAGE -target /` or the native Installer app.
The user enters the password locally, never in chat or an agent tool argument.
MacTraitor-Pro's passwordless `darwin-rebuild` rule does not authorize the agent
to run the package installer without authentication.

Immediately run `hey re` from the validated candidate checkout in a supervised
PTY. The installed `hey` may be older; `mise --cd CHECKOUT run rebuild switch`
runs that checkout's supported task. Seqeratop also needs interactive sudo and
may require an unlocked 1Password session for its existing activation hooks.
Do not claim success from the installer alone. Preserve the unpiped exit status
of the rebuild.

The activation guard uses `launchctl bootout system/org.nixos.nix-daemon`
when the old service remains loaded. On MacTraitor-Pro, nix-darwin's legacy
`launchctl unload` failed while removing the old plist, despite a zero rebuild
exit status. Check loaded services and processes, not just files or exit status.

The package can leave the old nix-darwin `nix.conf` symlink until activation.
After activation, require a real installer/Nixd-owned `nix.conf` that includes
`nix.custom.conf`. If either ownership is wrong, stop and recover rather than
letting both daemons run or hand-editing generated custom settings.

### Work-machine policy

Determinate defaults include telemetry and crash reporting. Its installer also
submits installation diagnostics. Review the [vendor telemetry policy](https://docs.determinate.systems/guides/telemetry/)
against Seqeratop's workplace requirements before installing there. Runtime
approval is not approval to add FlakeHub accounts, paid subscriptions, OTLP
exporters, enterprise bindings, or a Linux VM. This migration adds none of those.
No telemetry opt-in/out is made by the module. If workplace policy requires a
different setting, obtain the specific policy decision before that host changes.

## Acceptance on each host

Record the exact source SHA and `/run/current-system` target. Check all of:

1. The PATH-selected CLI and `/nix/var/nix/profiles/default/bin/nix` report the
   intended Determinate version. Record `determinate-nixd version` as well.
2. `launchctl print system/systems.determinate.nix-daemon` and `ps` identify the
   running Determinate daemon. `org.nixos.nix-daemon` must not remain loaded.
   A CLI version alone is not daemon evidence.
3. `nix.conf` belongs to Nixd; `nix.custom.conf` and `registry.json` resolve to
   the activated system's generated files. `nix config show --json` reports
   cores 2, max-jobs 6, root plus the correct primary user, all four extra caches,
   their signing keys, and the official cache/key. Do not log credentials.
4. `nix registry list` and a legacy `<nixpkgs>` lookup resolve the intended pin.
   Check the GC/optimise plists and confirm the Nixd GC strategy is disabled.
   Do not execute the deleting maintenance jobs as an acceptance test.
5. `nix store info --store daemon` succeeds. Build a small, fresh derivation
   through `--store daemon` and check its output, not merely its exit status.
   Verify `gh`, Python, Git, SSH, and the preserved fallback profile still run.

Only after MacTraitor-Pro passes may the coordinator assign Seqeratop the same
exact revision and these steps. Neither a portable CI success nor local Darwin
evaluation proves runtime acceptance on the second Mac.

## Emergency recovery without deleting the store

These are privileged recovery operations, not a routine generation rollback.
Use the saved paths from this host, not a different Mac's evidence. Keep a local
administrator terminal available throughout the handover.

1. Stop `systems.determinate.nix-daemon` with `launchctl bootout`. Inspect and
   stop any remaining Nix daemon before restoring one. Leave the Nix volume
   mounted and do not run either installer's uninstaller.
2. Preserve the failed runtime's configuration and plist under new backup names.
   Restore the saved upstream `nix.conf` as a real file, without writing through
   a store symlink. Restore the saved upstream plist to `/Library/LaunchDaemons`
   as root:wheel, mode 0644. Validate it again with `plutil -lint`.
3. Bootstrap `system/org.nixos.nix-daemon` from that plist. The saved definition
   uses the rooted upstream Nix executable directly, not the global profile.
   Use the independent fallback profile to check `store info --store daemon`
   and build/read a fresh small output. Check `ps` for the upstream executable.
4. With the daemon usable, restore the old Darwin configuration using the
   supported `hey` rollback/rebuild path, selecting the saved generation.
   Verify its revision, configuration ownership, and daemon executable. Retain
   the independent profile until recovery has passed these runtime checks.

Returning to a previous Determinate release is a separate operation using
`sudo determinate-nixd upgrade --version VERSION`. It does not restore upstream
Nix ownership. Never report either runtime recovery as tested unless the daemon
was actually restored and a build succeeded afterward.
