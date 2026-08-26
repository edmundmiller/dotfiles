# Worklog: fix-macos-audio-input-priority

Status: complete

## Objective

Keep the Nix-managed macOS audio input priority sorter continuously active so
the highest-priority available configured input wins after device and default
input changes, without changing the default output device.

## Decisions

- Preserve the existing declarative input order; do not infer a new order from
  the currently connected receiver's display name.
- Treat the installed app, launchd process, CoreAudio default-input readback,
  and unchanged default-output readback as the runtime verification surfaces.
- Use local-only landing authority: create reviewable commits, but do not push
  or merge.
- Keep the packaged menu app available, but run it in manual mode. A small
  repo-owned launchd worker enforces only input priorities, which guarantees
  that automatic correction cannot inspect or change the default output.
- Place the connected `Wireless Mic Rx` first by explicit user decision while
  preserving the relative order of every previously configured input.

## Evidence

- Checkout root is `/Users/emiller/.codex/worktrees/bcc3/dotfiles`, detached at
  `f064f0ff9c370f241cc6655f7e0393561553b8a9`, with a clean worktree and no
  rebase, merge, or worktree-local Git lock.
- Host is `MacTraitor-Pro.local`, Darwin arm64.
- The package is installed under `/Applications/Nix Apps`, but the application
  process and a matching launchd job were absent before changes.
- CoreAudio readback reproduced AirPods as the default input while the
  configured higher-priority built-in microphone and the unlisted wireless
  receiver were both available.
- The activated Nix preferences use `app.audioprioritybar`, while the installed
  app reads `com.example.AudioPriorityBar`; the two domains contain different
  input priority lists.
- The upstream v1.2.1 source registers listeners for device-list, default-input,
  and default-output changes. It also auto-selects an output at startup and on
  every device change, so launching it continuously requires an explicit
  input-only policy.
- `audio-priority-bar-regressions` first reproduced the three defects as strict
  expected failures, then passed against the input-only worker. Its fake
  CoreAudio surface verified top-available selection and rejected output calls.
- The first `hey re` attempt failed before activation because the launchd
  priority-file argument was a derivation rather than a plist string. A new
  serialization assertion reproduced the failure before the path was coerced.
- The complete host closure is independently blocked by an `h5py` test abort
  in the Hermes dependency chain. The focused Nix-built audio plist and worker
  were already available, so the exact generated plist was installed and
  verified byte-for-byte without changing that unrelated package.
- `launchctl` reports the Nix-store sorter running with a live PID, one run,
  and no exit. Its log records selection of `Wireless Mic Rx`; stderr is empty.
- The corrected preferences domain contains all 14 configured inputs with the
  wireless receiver at rank 1 and manual output mode enabled.
- A CoreAudio readback reported `Wireless Mic Rx` as default input. After a
  forced change to the built-in microphone, the same live worker reasserted the
  receiver within two seconds; the default output remained MacBook Pro
  Speakers before and after. A direct `--once` invocation also confirmed the
  receiver was already preferred without changing output.
- Run receipt:
  `/Users/emiller/.local/state/dotfiles-agent-runs/98d657bf030d/20260825T234609Z-8b084cb8c592.json`.

## Reviews

- Plan gate: preserve the existing priority list, add a user launch agent for
  the installed app, then exercise both default-input correction and
  default-output non-interference on the live host.

## Feedback

None yet.

## Remaining work

None within the local-only audio task. A future full `hey re` still depends on
the unrelated Hermes `h5py` build failure being resolved upstream or elsewhere.

## Commits

- `9a968fa31 test(audio): capture priority sorter regressions`
- `fix(audio): keep input priority sorter active` (this commit)
