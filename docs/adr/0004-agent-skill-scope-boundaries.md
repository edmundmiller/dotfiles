# ADR 0004: Keep dotfiles-local skills out of the global skills target

## Status

Accepted

## Context

This repository has two skill lanes that look similar but have different scopes:

- `skills/` contains global agent skills that are useful across projects.
- `.agents/skills/` contains skills that are only useful when agents are working in this dotfiles repository.

The global runtime target is `~/.agents/skills`, which is discovered by Codex, Pi, OpenCode, Hermes, and Claude through its bridge. Accidentally copying dotfiles-local skills into that target makes project-specific guidance appear in unrelated repositories and blurs whether a skill is global or local.

This mistake happened when `.agents/skills` was briefly wired into the Home Manager `agent-skills` bundle. The resulting deployment put dotfiles-local skills such as `healthchecks-io`, `pi-nix-syntax`, and `oracle` into `~/.agents/skills`.

`~/.agents/skills` is not exclusively owned by this repo: manually installed or manually created global skills are allowed there. The invariant is narrower: this repo's project-local `.agents/skills/*` entries must not appear in the global target.

## Decision

`skills/` is the source for global, cross-project agent skills. Those skills may be deployed to `~/.agents/skills` by `hey re` through the Nix/Home Manager `agent-skills` activation.

`.agents/skills/` is the source for dotfiles project-local skills. Those skills may be checked into this repository and used as local agent context while working here, but they must not be included in the global `agent-skills` bundle or copied to `~/.agents/skills`.

A package-owned skill may still be installed globally when it is explicitly wired as a global skill because it is useful across projects. `packages/jut/skill` is such an exception. This exception does not apply to `.agents/skills/`.

`hey re` must fail before rebuilding if any skill name from this repo's `.agents/skills/<name>/SKILL.md` is present at `~/.agents/skills/<name>/SKILL.md`. The check is name-based. If a same-named skill should become global, move or rename it into the global skill lane instead of keeping it in `.agents/skills`.

A guarded cleanup command, `hey skills-cleanup-local-leaks`, removes only exact name intersections between this repo's `.agents/skills` and `~/.agents/skills`.

## Consequences

- Project-specific dotfiles skills do not leak into unrelated repositories.
- Future agents have an explicit boundary: add global skills under `skills/`; add dotfiles-only skills under `.agents/skills/`.
- `~/.agents/skills` may still contain manually installed or manually created global skills.
- The current `agent-skills` sync behavior and manual global skill preservation remain a known tension. This ADR does not solve global target ownership broadly; it only prevents dotfiles-local skill leakage.
