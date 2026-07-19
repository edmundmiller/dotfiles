# Worklog: root-ponytail-cuts

Status: active

## Objective

Remove every accepted, evidence-backed root ponytail-audit finding without touching unrelated work. Stop when focused evaluation, Darwin rebuild, repository checks, landing review, commit, rebase, push, and upstream verification pass.

## Decisions

- Delete: `autoresearch.md`, `autoresearch.jsonl`, `tools/linear/`, `bin/rebuild-darwin.sh`, `bin/generate-module-docs`, `bin/cleanup_after_start`, `.gate`, empty `bin/rofi/networkmenu`, empty `bin/rofi/spotifymenu`, and duplicate `bin/piu`.
- Remove zero-consumer definitions: `toCSSFile`, `mkDarwinOnlyConfig`, `genAttrs'`, `mapModules'`, and `isNixOS`.
- Remove zero-consumer flake inputs: `google-workspace-cli` and `nixos-hardware`, including lock data through `nix flake lock`.
- Keep unrelated NUC, Hermes, mo, and OpenWiki working-tree changes untouched.
- Consolidate Pi updates on the shell `piu()` implementation.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin arm64.
- Pre-edit workspace contains unrelated changes under `hosts/nuc/`, `modules/shell/mo/`, and `.github/workflows/`.
- Whole-tree FFF and bounded searches found no consumers for every targeted definition, script, artifact, tool flake, or input.
- Verification surfaces: lock regeneration, focused Nix evaluation, `hey check`, full Darwin rebuild, agent audit/finish, and heterogeneous landing review.
- Focused Darwin evaluation initially caught an over-aggressive `attrValues` import removal; restored it because `mapModulesRec'` still uses it.
- `nix eval --raw .#darwinConfigurations.MacTraitor-Pro.system.drvPath` passed after correction.
- `hey agent-audit-tests flake.nix lib/attrs.nix lib/generators.nix lib/modules.nix lib/platform.nix`: `PASS test-confidence`.
- `hey check`: all Darwin-compatible checks passed.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .`: build and activation passed.
- `TERM=xterm-256color zsh -lic 'whence -v piu; ...'`: fresh interactive login resolves `piu` to the retained shell function; the earlier false negative used tool-default `TERM=dumb`, which skips the interactive rc branch.

## Reviews

- OpenCode plan review initially lacked the accepted list; resolved by recording it above. Its rerun flagged pre-existing unrelated dirt as a scope mismatch; non-applicable because the plan explicitly excludes those paths and no target edits existed when the plan gate ran.
- OpenCode landing review: conditional pass. All targeted removals were safe; the condition is selective staging so pre-existing NUC, mo, and OpenWiki dirt remains excluded. Its full-flake failure came solely from an untracked NUC helper referenced by that unrelated dirt; Darwin and scoped checks passed.

## Feedback

None.

## Remaining work

Run landing gates, commit, rebase, rebuild from clean Git source, smoke `piu`, push, and verify upstream.

## Commits

Pending.
