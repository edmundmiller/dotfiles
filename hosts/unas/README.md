<!-- Human docs for UNAS host: deploy, identity policy, and storage layout. -->

# UNAS

NixOS NAS host (`hosts/unas/`).

## Identity (public-safe)

- MAC (redacted): `d4:5d:64:**:**:**` (ASUSTek OUI)
- Keep full MAC out of public git.
- If IP drifts, resolve from router DHCP leases using MAC prefix.

## Deploy

From repo root:

```bash
hey unas
```

SSH helper:

```bash
hey unas-ssh
```

## Key files

- `default.nix` — host imports + enabled modules
- `disko.nix` — disk + ZFS pool layout
- `nas.nix` — NFS exports + firewall
- `modules/time-machine.nix` — Time Machine via netatalk
- `backups.nix` — restic backup job
- `users.nix` — local users/groups

## Notes

- Host may be powered off / stale if unused for long periods.
- If deploy fails with SSH refused, enable sshd from local console first.
