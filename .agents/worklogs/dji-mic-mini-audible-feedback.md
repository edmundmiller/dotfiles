# Worklog: dji-mic-mini-audible-feedback

Status: active

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

## Reviews

Provenance and activation reconnaissance found no existing dotfiles or Nix
owner. A focused test-design review is in progress.

## Feedback

None.

## Remaining work

- Adopt exact baseline source and rule with host-scoped ownership.
- Add expected-failure public-CLI feedback tests, then implement the fix.
- Run focused checks, review, local commits, and narrow activation assessment.

## Commits

None.
