# Worklog: fix-headless-skill-routing

Status: active

## Objective

Remove the final active references to the retired `config/agents/skills`
layout, and make headless bootstrap install checkout-owned shared skills through
the harness-neutral discovery surface.

## Decisions

- Link valid checkout-owned `skills/catalog/*/SKILL.md` directories into
  `~/.agents/skills`; keep `~/.pi/agent/skills` reserved for Pi-targeted skills.
- Preserve existing non-symlink targets instead of overwriting Nix-managed or
  user-owned content.
- For custom checkout paths, make `~/.config/dotfiles` the repository symlink;
  do not create a real directory and accidentally nest the link inside it.
- Keep dotfiles-only procedures under `.agents/skills` and shared procedures
  under `skills/catalog`.
- Document package-native Pi skills and Pi-targeted remote skills as explicit
  exceptions instead of imposing an invalid blanket empty-array rule.

## Evidence

- A behavior-level bootstrap regression failed before the source fix because no
  shared skill was installed; it passes afterward.
- The bootstrap regression runs twice in an isolated home, preserves an
  existing real directory, ignores invalid catalog entries, installs only valid
  catalog skills, confirms that no Pi-target copy is created, and verifies the
  custom-checkout compatibility symlink itself.
- A cross-file Pi skill regression failed on the retired path before the skill
  update; it now verifies the catalog, project-local, remote-lock, and Pi-only
  target contracts against the current child flake.
- All 13 `tests.test_agent_instruction_wiring` cases pass.
- `bash -n bin/bootstrap`, `git diff --check`, and the `pi-nix-syntax` skill
  validator pass.

## Reviews

- A scope audit identified both stale paths as P2 runtime/procedural gaps.
- Bootstrap design review confirmed `~/.agents/skills` as the correct target and
  required preserving existing non-symlink entries for idempotency.
- Pi skill review identified the package-native and Pi-targeted exceptions plus
  the required child-lock/parent-sync procedure; all are reflected here.
- Final diff review found and reproduced the custom-checkout nested-link bug;
  the behavioral regression now covers the corrected symlink shape.
- Follow-up review found no remaining P1/P2 issues after that correction and
  confirmed the bootstrap behavior on Darwin/Linux-compatible symlink semantics.

## Feedback

- When a source layout is retired, validate executable bootstrap paths and
  active procedural skills in addition to runtime modules; source-only wiring
  checks can miss a silent no-op installer.

## Limitations

- Headless bootstrap links checkout-owned catalog skills. It does not
  materialize remote or transformed child-flake selections; that would require
  a separately exposed configured install package or app.

## Remaining work

- Run repository gates, obtain final diff review, commit and publish this repair,
  then verify native GitHub Linux and Darwin CI at the landed revision.

## Commits

The isolated compatibility commit and annotated tag will be recorded after
landing.
