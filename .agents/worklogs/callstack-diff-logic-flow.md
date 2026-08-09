# Worklog: callstack-diff-logic-flow

Status: complete

## Objective

Determine why `callstack-diff` was missed for the grievance-routing logic flow, correct the narrowest repository defect if one exists, and stop when a fresh agent is guided to the intended workflow, focused checks and a real CLI exercise pass, and the landed branch is verified upstream.

## Decisions

- Investigate package behavior, skill discoverability, history, and the real CLI before editing; the handoff does not establish which layer is defective.
- Keep the grievance endpoint as an input example only. Do not implement its service, Linear, PostHog, or Cloudflare integrations.
- Classified the miss as a skill discoverability/guidance defect: the existing renderer supports the flow once modeled as minimal TypeScript, but the package-local skill was not globally deployed and did not describe prose architecture inputs.
- Made `skills/catalog/callstack-diff/SKILL.md` canonical, retained `packages/callstack-diff/SKILL.md` as a relative development symlink, and taught Nix packaging to copy and compare the canonical file.

## Evidence

- `jj root --ignore-working-copy` — confirmed this Herdr-created checkout is Git-only (`no jj repo`).
- `hostname && uname -a && git rev-parse --show-toplevel && git status --short --branch` — confirmed `MacTraitor-Pro.local`, Darwin arm64, the assigned `worktree-calm-stone-5371` checkout, and a clean `worktree/calm-stone-5371` branch.
- History at package origin `1e11493da` and skill command commit `4bb3b8e3` confirmed the intended renderer remained static JS/TS; no prose renderer had existed.
- A real grievance-routing model rendered one shared prefix followed by `deduplicateAndEnrich`, `retainRawReport`, and separate PostHog and Linear branches through both the development CLI and `./result/bin/csd`.
- `bun run test -- tests/csd.test.ts` failed on the new prose-flow guidance assertion before implementation, then passed all 13 tests after the skill correction.
- `bun run lint` passed; `bun run test` passed 18 tests across 2 files. `bun run evals` loaded the suite but its one live case skipped without opt-in, so it is recorded as exercised but not a pass.
- `nix build .#callstack-diff` passed, including the packaged skill comparison and install checks.
- `python3 skills/catalog/skill-quality/scripts/validate.py skills/catalog/callstack-diff` passed with 1 skill checked and 0 findings.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` completed and deployed the canonical skill to `~/.agents/skills/callstack-diff/SKILL.md`; a direct read confirmed the new trigger metadata and prose-flow workflow.
- `hey check`, `hey agent-audit-tests`, and the final `hey agent-finish --worklog .agents/worklogs/callstack-diff-logic-flow.md` passed. The first finish attempt formatted `implementation-notes.html`; the rerun passed every applicable gate.

## Reviews

- The required `skill-reviewer` subagent was attempted but unavailable because its runtime had no model selected. Deterministic skill validation and direct CLI exercise remain successful.
- `code-simplifier` reviewed the four implementation surfaces and made no edits because the source-of-truth relationship and single behavior assertion were already minimal.
- Final `sem diff`, scoped skill-path search, raw symlink mode check, and the complete `tests/csd.test.ts` file confirmed consistent callers, minimal scope, and sibling-test coverage.

## Feedback

None yet.

## Remaining work

None.

## Commits

- `76490389c` — make callstack logic flows discoverable.
