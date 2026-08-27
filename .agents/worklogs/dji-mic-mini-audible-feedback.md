# Worklog: dji-mic-mini-audible-feedback

Status: blocked

## Objective

Own the existing receiver-scoped DJI Mic Mini mute automation in dotfiles and
play distinct mute/unmute sounds only after an exact `Wireless Mic Rx` input
mute transition is read back successfully.

## Decisions

- Preserve the existing Karabiner trigger: one receiver-scoped
  `volume_increment` event invokes one non-repeating `toggle` command.
- Resolve the receiver by exact CoreAudio UID, name, and manufacturer; never
  inspect or mutate default devices, output state, AirPods, firmware, or DJI
  settings.
- Serialize toggles, bound mute readback to 300 ms, and launch Basso/Tink only
  after the requested state transition is verified.
- Keep the package and its Swift/CoreAudio regression check Darwin-only and run
  both DJI checks through the standard Darwin `hey check` gate.
- After the supported Darwin switch failed twice in an unrelated dependency,
  activate only the two evaluated Home Manager source paths and preserve the
  previous helper as a recoverable backup.

## Evidence

- The task is rebased onto `origin/main` revision `42f03b84c` with only the DJI
  implementation, tests, host enablement, standard-gate wiring, and this
  worklog changed.
- The public `toggle` fixture proves lock/resolve/read/write/readback/unlock/
  sound ordering, one Basso sound for mute, one Tink sound for unmute, and no
  sound for missing or ambiguous receiver, setter failure, mismatch, no-op, or
  timeout.
- Production-source guards reject CoreAudio output scope, default-device
  selectors, and AirPods/Bluetooth APIs. Real system invariants are checked by
  live readback rather than fake sentinel state.
- Direct fixture, ShellCheck, package build, Darwin regression check, platform
  boundary check, `hey agent-audit-tests`, and `hey check --worktree` pass.
  The standard gate reports `DJI Mic Mini checks OK`.
- Linux exposes neither the Darwin-only package nor its CoreAudio regression
  check. A dedicated Darwin boundary check also enforces standard-gate
  selection.
- Standards review found no remaining actionable issue. Spec review confirmed
  the exact UID/name/manufacturer, input-only mute, bounded readback, and
  post-verification sound design; concurrency beyond the exercised lock/event
  contract remains intentionally outside the minimal fixture.
- A normal `hey re` and one resource-limited retry both stopped before
  activation because upstream `python3.12-h5py-3.15.1` pytest aborted with exit 134. No unrelated Hermes or h5py policy was changed.
- Nix evaluation resolves the helper to
  `/nix/store/xggypng07szwmdv6v18xk2iyzkr6fdm2-dji-mic-mini-receiver-mute-0-unstable-2026-08-25/bin/dji-mic-mini-receiver-mute`.
  The live helper now symlinks to that exact path and has SHA-256
  `d3c630359a7386b7a99809f98dd901c8c7d6de5d2eb3ff866f15e0e6496f8eb9`.
- The evaluated Karabiner asset is also installed as its exact Nix-source
  symlink. The active Karabiner config still contains exactly one matching DJI
  rule with vendor `11427`, product `16401`, consumer scope, and `repeat: false`.
- The previous live helper remains at
  `~/.local/bin/dji-mic-mini-receiver-mute.bkup` with its original SHA-256
  `22e4b28bc57382bac846c3e268ffbcbf0ca9796e7a6965f60c30104ad714e0c3`.
- Before the long build, the exact receiver enumerated and reported mute on.
  During the build it disconnected or powered down; the Mac fell back from
  `Wireless Mic Rx` to `MacBook Pro Microphone`. Output remains `MacBook Pro
Speakers`, muted at volume 31. No audio or default-device state was changed.

## Reviews

Two fixed-point reviews covered specification and repository standards.
Platform leakage, skipped standard-gate checks, a tautological fixture, and
obsolete expected-failure branches were corrected. Final standards review is
clean.

## Feedback

- Current `origin/main` cannot complete a Darwin switch on this Mac because the
  unrelated h5py test suite aborts reproducibly. The exact-path activation is
  intentionally narrower than changing or bypassing that package.

## Remaining work

- Wake or reconnect the DJI receiver, make a Mac output audible, then arm
  readback and perform two quick transmitter-button taps. Verify mute on/off,
  one distinct sound per transition, receiver enumeration, the single scoped
  rule, and unchanged input/output defaults and output volume/mute.
- After the unrelated h5py failure is repaired upstream or in its owning task,
  run `hey re` again so Home Manager adopts the already-matching live symlinks.

## Commits

- `8be86a8a7` `chore(dji-mic): adopt receiver mute automation`
- `36d6085fd` `test(dji-mic): specify verified feedback`
- `1168ae7dc` `feat(dji-mic): add verified mute feedback`
- `ab75cbad2` `docs(worklog): record DJI activation blocker`
- `5c177cdbe` `test(dji-mic): specify Darwin-only flake boundaries`
- `fc9704f38` `fix(dji-mic): enforce Darwin-only package boundaries`
- `ed5af5a97` `test(dji-mic): require standard-gate coverage`
- `a6fefdbb2` `fix(dji-mic): run checks in standard gate`
- `7bb27a3f7` `test(dji-mic): remove obsolete xfail path`
- `d64624ee3` `test(dji-mic): simplify boundary assertion`
