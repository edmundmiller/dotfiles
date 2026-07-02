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

Only symlink deterministic guardrail files under `~/.omp/agent`. Treat the rest
as OMP-owned mutable runtime state.

Enable with:

```nix
modules.agents.omp.enable = true;
```

## Docs

- [message-queue.md](./message-queue.md) — the three message-queue knobs
  (`interruptMode` / `steeringMode` / `followUpMode`) with a flow diagram.
  Also tracks the pending OMP + Herdr theme fix.
