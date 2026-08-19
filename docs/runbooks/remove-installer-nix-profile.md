---
purpose: Remove the stale Determinate nix-installer root profile that shadows nix-darwin's Nix.
applies_to: Any nix-darwin Mac whose `nix` resolves to an old installer-managed version instead of the system one.
entrypoint: Confirm the shadow (`which nix`), then follow the removal order below.
verification: `nix --version` reports the system version and no installer artifacts remain.
update_when: nix-darwin or the installer changes the profile/hook layout.
---

# Runbook: Remove Installer Nix Profile

## Symptoms

- `which nix` resolves outside `/run/current-system/sw` (e.g. the installer
  profile) or `nix --version` lags `/run/current-system/sw/bin/nix --version`
- `/nix/receipt.json` exists — the machine was installed by the Determinate
  Systems `nix-installer` (v0.32.2 here), which owns a root profile and a
  self-repair hook

The installer profile is a **shadow**: it prepends its own `bin` to PATH via
`/etc/zshrc` + `/etc/profile.d/nix.sh`, hiding the nix-darwin-managed nix at
`/run/current-system/sw/bin/nix`. All live consumers (daemon, GC, optimise
plists, nix.conf) point at the system nix; the profile is dead weight.

## The two traps

1. **Repair hook undoes bare deletions.** `systems.determinate.nix-installer.nix-hook`
   runs `/nix/nix-installer repair` at every boot (`KeepAlive` on failure) and
   re-asserts shell-profile state. Kill it first or the profile and shell
   blocks return at next boot.
2. **Never run `/nix/nix-installer uninstall`.** It reverses the whole receipt,
   including `create_nix_volume`, and destroys the APFS store volume nix-darwin
   depends on. Surgical removal only.

## Removal order

### 1. Kill the repair hook

```bash
sudo launchctl bootout system/systems.determinate.nix-installer.nix-hook
sudo rm /Library/LaunchDaemons/systems.determinate.nix-installer.nix-hook.plist
```

Verify: `launchctl print system/systems.determinate.nix-installer.nix-hook` → not found.

### 2. Remove the root profile and reclaim its store paths

```bash
sudo rm /nix/var/nix/profiles/default
sudo rm /nix/var/nix/profiles/per-user/root/profile /nix/var/nix/profiles/per-user/root/profile-2-link
sudo nix-collect-garbage -d
```

GC may lazily recreate a dangling `/nix/var/nix/profiles/default` symlink
(target gone) — harmless; remove it at the end.

### 3. Strip the shell sourcing blocks

```bash
sudo sed -i '' '2,6d' /etc/zshrc
sudo rm /etc/profile.d/nix.sh
```

Both blocks are guarded by `[ -e /nix/var/nix/profiles/default/... ]`, so they
no-op once the profile is gone — this step is cruft removal, not a fix.

### 4. Remove the installer itself

```bash
sudo rm /nix/receipt.json /nix/nix-installer
```

This kills the repair capability for good.

## Keep intact

- `/etc/synthetic.conf` `nix` entry (mounts the store volume at boot)
- nixbld users (the daemon builds with them)
- `/etc/nix/nix.conf` and all `org.nixos.*` launchd plists (nix-darwin-owned)
- `~/.nix-profile` (user profile: antidote, nix-direnv — separate from root)

## Verify

```bash
which nix                      # → /run/current-system/sw/bin/nix
nix --version                  # matches /run/current-system/sw/bin/nix --version
launchctl print system/systems.determinate.nix-installer.nix-hook  # → not found
ls /nix/nix-installer /nix/receipt.json /Library/LaunchDaemons/systems.determinate.nix-installer.nix-hook.plist  # → no such file
```

## Residual

nix-darwin's set-environment still lists `/nix/var/nix/profiles/default` in
`NIX_PROFILES`/PATH — a dead path, silently skipped. Harmless; clean it in a
nix-darwin rebuild if you want zero mentions.
