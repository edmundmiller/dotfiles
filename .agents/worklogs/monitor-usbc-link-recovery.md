# Worklog: monitor-usbc-link-recovery

Status: active

## Objective

Add a durable, safe dotfiles-owned way to detect the recurring TS5 DisplayPort
link-training failure, explain the discriminating evidence, and perform only
explicitly requested recovery actions. Stop when the public interface is
tested, the Darwin configuration builds, and the live diagnostic correctly
classifies the current `HPD High` / `SinkCount 0` / `No Link` path.

## Decisions

- Work from an isolated Git worktree at current `origin/main`; preserve the
  unrelated dirty canonical checkout byte-for-byte.
- Treat physical topology, cable capability, and monitor input as hardware
  facts. Do not encode a display arrangement or an undocumented automatic
  hardware reset as if it were a verified fix.
- Keep activation and publication separate from source implementation until
  they are explicitly authorized and independently verified.
- Extend the already-installed `displayctl` boundary with a read-only
  `macos status` command instead of adding a second host CLI.
- Poll through a five-minute, non-resident LaunchAgent. Persist an incident
  fingerprint, notify once per unchanged incident, and never restart
  WindowServer, write display defaults, reboot, or power-cycle hardware.
- Treat absent hardware as `unobserved`, not healthy; treat partial or
  inconsistent USB-C transport records as degraded.

## Evidence

- Live macOS 27 I/O Registry: TS5 on Mac USB-C port 1 at 40 Gb/s; ASUS
  `XG32UCWMG` active on DP tunnel 0; DP tunnel 1 reports `HPD High`,
  `SinkCount 0`, `No Link`, `Active No`, and zero lanes.
- Mac USB-C port 2 is empty; port 3 carries only the DJI Wireless Mic Rx.
- Prior same-machine recovery succeeded after moving the TS5 host cable from
  port 1 to bottom-left port 2, but this is a topology test rather than proof
  of a permanent software fix.
- TDD red: the fixture-backed `displayctl macos status` regression failed at
  argument parsing before implementation; the host regression then failed all
  three initial LaunchAgent assertions.
- TDD green: `python3 -m unittest -v test_displayctl.py` passes 36 tests, and
  both `displayctl-tests` and `display-link-guard-regressions` build through
  the aarch64-darwin flake checks.
- `hey check --worktree` passes Darwin evaluation, formatting, hooks, tmux,
  package harness, package policy, and ast-grep checks.
- The built package's live, read-only status reports `state=unhealthy`, TS5 on
  port 1 instead of configured port 2, DP tunnel 0 linked, and DP tunnel 1 at
  `HPD High` / `SinkCount 0` / `No Link`; it exits 1 as designed.
- A complete `MacTraitor-Pro.system` build reached and built the new
  `org.nixos.display-link-guard.plist`, then failed in the unrelated existing
  Hermes/ML closure when the `h5py` pytest process aborted. No changed path
  owns that dependency.

## Reviews

- Standards review found false-health handling, KeepAlive assertion, durable
  state-write, source/readback documentation, and partial-record parser gaps.
  Each was fixed and covered; the final re-review passed with no findings.
- Spec review found missing isolation/escalation guidance, duplicated recovery
  notification text, and an unclear activation boundary. The runbook now
  covers the physical branches, the guard reads recovery from checked-in
  config, and documentation says explicitly that behavior starts only after
  activation.

## Feedback

- Building the whole Darwin system closure pulled 53 unrelated uncached
  dependencies. The focused config, package, LaunchAgent plist, and behavioral
  checks provide task-specific proof; the full closure remains blocked by the
  unrelated `h5py` abort and must not be reported as passing.

## Remaining work

- Activation is not authorized. After explicit approval, run the repository's
  normal Darwin activation, read back
  `gui/$(id -u)/org.nixos.display-link-guard`, and re-run the packaged status.
- Publication/landing is not authorized. The local branch remains isolated
  from the dirty canonical checkout and from `origin/main`.
- Physical recovery remains explicit: move the TS5 host cable to bottom-left
  port 2; if needed, disconnect ASUS, wait for LG, then reconnect ASUS.

## Commits

- `bf8c052d7 test(displayctl): capture macOS link training regression`
- `377625f16 feat(mactraitorpro): guard TS5 display links`
