# ADR 0005: Export Pi agent environment from the launcher wrapper

## Status

Accepted

## Context

Some tools change their output format when they know they are being run by an
agent. For example, test runners and helper scripts can use `AGENT=1` to emit
more concise, machine-actionable output.

Pi already sets `PI_CODING_AGENT=true` for sessions, and repo tooling such as
`hey re` treats that as agent mode. That is sufficient for commands that know
about Pi specifically, but it does not help generic tools that only check the
common `AGENT=1` convention.

A Pi extension could set `process.env.AGENT = "1"`. That would affect many child
processes spawned after extensions load, because they usually inherit Pi's Node
process environment. However, an extension is not the right process boundary for
this invariant:

- extensions run after Pi has already started;
- `--no-extensions` or an extension load failure would skip the behavior;
- any startup work before extension initialization would not see the variable;
- this is launch/runtime environment configuration, not agent behavior logic.

This repository already wraps the Nix-managed Pi executable in
`modules/agents/pi/default.nix` to provide runtime environment fixes and guard
Nix-store-specific behavior such as `pi update`.

## Decision

Set the agent environment in the Nix-managed Pi launcher wrapper, before the
real Pi executable is invoked:

```bash
export AGENT=1
export PI_CODING_AGENT=true
```

Do not implement this via a Pi extension. Extensions may still rely on these
environment variables, but they are not responsible for establishing them.

## Consequences

- The Pi process and subprocesses spawned by Pi inherit `AGENT=1` from startup.
- Generic tools such as `bun test` can detect agent execution without knowing
  about Pi-specific variables.
- The behavior works even when extensions are disabled or fail to load.
- The behavior is reproducible through Nix/Home Manager rebuilds.
- The variable only applies to processes launched through the wrapped `pi`
  executable; ordinary user shells remain unaffected.
