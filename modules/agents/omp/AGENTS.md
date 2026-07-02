# OMP Module

Thin wrapper module for Oh My Pi (`omp`).

Keep OMP isolated from Pi. This repo exports Pi globals such as
`PI_CODING_AGENT_DIR=$HOME/.pi/agent`; plain OMP honors those and will collide
with Pi state. The module installs `pkgs.llm-agents.omp` through a wrapper that
sets:

```sh
PI_CONFIG_DIR=$HOME/.omp
PI_CODING_AGENT_DIR=$HOME/.omp/agent
PI_PERMISSION_SYSTEM_CONFIG_PATH=$HOME/.omp/agent/extensions/pi-permission-system/config.json
```

`~/.omp/agent/config.yml` is tracked from `config/omp/config.yml`; edit the
repo source, not the runtime symlink. The `permission-policy-guard` extension
package is linked from `config/omp/` and explicitly listed in `config.yml`; it
blocks OMP tool calls that target `config/pi/pi-permission-system.jsonc`.
Other OMP runtime state remains mutable and OMP-owned.

Enable with:

```nix
modules.agents.omp.enable = true;
```

## Per-host model roles

`modules.agents.omp.smolModel` sets `PI_SMOL_MODEL` in the wrapper for a
declarative per-host smol/fast model (also drives commit, which falls back to
smol). This is the _only_ role exposed via Nix: OMP has no env override for
default/commit, and `--config` overlays crash the `config` subcommands, so the
env var is the clean lever. default/slow/plan stay in the mutable
`config.yml` and are identical across hosts. Precedence: `--smol` flag >
`PI_SMOL_MODEL` > `config.yml`.

## Docs

- [message-queue.md](./message-queue.md) — the three message-queue knobs
  (`interruptMode` / `steeringMode` / `followUpMode`) with a flow diagram.
  Also tracks the pending OMP + Herdr theme fix.
