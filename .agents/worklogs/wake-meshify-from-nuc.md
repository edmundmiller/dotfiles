# Worklog: wake-meshify-from-nuc

Status: complete

## Objective

Install a declarative `wake-meshify` command on the NUC and prove that invoking it sends a Wake-on-LAN packet to Meshify.

## Decisions

- Use the repository-managed NixOS configuration so the command survives rebuilds.
- Preserve the existing unrelated worktree files.
- Target the NUC's wired `/24` broadcast address `192.168.1.255`; the live neighbor table confirmed Meshify's MAC.

## Evidence

- `ssh nuc`: host `nuc`, user `emiller`, wired address `192.168.1.222/24`.
- Live neighbor table: `192.168.1.250` has MAC `a8:5e:45:51:a2:e0`.
- Focused check `checks.x86_64-linux.nuc-wake-meshify`: red before implementation, green after implementation.
- `hey nuc-wt` dry activation completed and produced system `/nix/store/a0ha8ji8sm7dx8pznrm6h0wk2vqh449s-nixos-system-nuc-26.11.20260714.18b9261`.
- Live `/run/current-system` points at that system; `/run/current-system/sw/bin/wake-meshify` exists.
- Runtime invocation reported one valid hardware address and one magic packet sent to `192.168.1.255:9`.
- Tailscale reported `meshify-1` active with direct endpoint `192.168.1.250:41641`.
- Deployment returned nonzero only after system activation because unrelated `home-manager-emiller.service` rejected an unmanaged `~/.agents/skills` directory without its marker.
- `hey agent-audit-tests`: PASS.
- `hey agent-finish`: focused Darwin evaluation, package tests, agent rules, skill quality, and test confidence passed; repo-quality failed because pre-existing `.agents/worklogs/audit-agent-worktrees.md` exceeds the 500 KB large-file limit.

## Reviews

- Final semantic diff reviewed; one feature binding, one package-list addition, one check, and matching NUC documentation.

## Feedback

- Avoid overlapping `hey nuc-wt build` and `hey nuc-wt` because build mode does not take the deployment lock; concurrent Nix 2.35 builds crashed with `Assertion '!awake.empty()' failed`.

## Remaining work

- None.

## Commits

- `feat(nuc): add Meshify wake command`
