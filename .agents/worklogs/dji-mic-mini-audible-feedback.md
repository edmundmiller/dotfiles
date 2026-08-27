# Worklog: dji-mic-mini-audible-feedback

Status: blocked

## Objective

Adopt the existing receiver-scoped DJI Mic Mini mute automation into dotfiles,
add distinct mute/unmute sounds only after a verified exact-input transition,
and stop after local commits unless a narrow activation path is proven.

## Decisions

- Preserve the live Karabiner rule exactly; change only the helper `toggle`
  behavior after baseline adoption.
- Treat the projectless Swift source and exported rule as the provenance
  baseline because the installed helper is byte-identical to its compiled
  artifact and no Git or Nix source exists.
- Do not run a broad Darwin switch while unrelated activation work is present.
- Treat manual copying or symlinking into live paths as unproven activation;
  repository ownership is through Home Manager and its supported entrypoint is
  the full Darwin rebuild.

## Evidence

- Clean isolated start at `origin/main` revision `17825e142`.
- Baseline source SHA-256: `48991b5e17ea3ca7bd5a49e0d814cf7c8f4f9bdf03efbf963274ba0eb9817ba2`.
- Baseline rule SHA-256: `3c8019bc4162fdab1dce7d4154bbfc1ac11a2350a35cd269391e01ddf6402152`.
- Installed helper SHA-256: `22e4b28bc57382bac846c3e268ffbcbf0ca9796e7a6965f60c30104ad714e0c3`.
- Live rule equals the exported provenance rule; the current helper reports
  receiver input mute off at provenance intake.
- The adopted source and rule are byte-identical to their provenance artifacts.
- The focused Nix package builds, and host evaluation routes the existing
  helper path plus Karabiner asset path to the managed sources.
- A delegated read-only probe accidentally toggled the receiver and restored
  it to off. A later read-only package status observed mute on, so current live
  state is not acceptance evidence and must be re-read before any activation.
- Commit `aa0f22417` records the strict expected-failure public-CLI regression
  suite. Before implementation it passed as an expected compile failure; once
  the helper seam compiled, the marker correctly failed with `unexpected pass`.
- Commit `0e64b9c45` adds advisory serialization, exact receiver identity
  validation, a 300 ms bounded readback, transition checks, and asynchronous
  Basso/Tink feedback after the lock is released and only on verified toggles.
- The fixture calls the literal `toggle` CLI command. It proves exactly one
  distinct sound after mute and unmute, no sound for missing/ambiguous receiver,
  setter failure, mismatch, no-op, or timeout, and unchanged mutable
  default/output/AirPods sentinels.
- Direct fixture test, ShellCheck, the focused package build, and the flake
  regression check pass. The built helper's read-only `status` resolves the
  exact receiver and currently reports mute on.
- `hey check --worktree` passes Darwin evaluation, formatting/pre-commit,
  zunit, package harness/policy, and ast-grep checks.
- The managed Karabiner rule still equals the unique live rule object and its
  provenance artifact. The live config and helper hashes remain unchanged.
- No narrow repository activation command exists. `hey re` and `hey test`
  both invoke a full `darwin-rebuild`; no activation was attempted.

## Reviews

Provenance and activation reconnaissance found no existing dotfiles or Nix
owner. Focused test-design review selected a compiled fixture backend at the
public `toggle` CLI seam so tests never touch live CoreAudio. Landing reviewers
identified a tautological sentinel check, a discarded pre-read, and positional
tuple fields; all were corrected and both reviewers confirmed resolution.

## Feedback

None.

## Remaining work

- Activate through a safe full Darwin generation after unrelated changes are
  cleared, or establish and separately authorize a supported narrow Home
  Manager activation path.
- Arm observation before two physical receiver-button taps, then verify mute and
  unmute sounds plus exact-input, default/output, AirPods, enumeration, rule
  scope, and one-sound-per-transition invariants.

## Commits

- `4cd8e8137` `chore(dji-mic): adopt receiver mute automation`
- `aa0f22417` `test(dji-mic): specify verified feedback`
- `0e64b9c45` `feat(dji-mic): add verified mute feedback`
