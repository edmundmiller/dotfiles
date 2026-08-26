# Worklog: workspace-ecm

Status: active

## Objective

Pin the landed agents-workspace cross-profile Kanban fix, deploy it to the NUC,
and stop only after a fresh owner-authenticated Buzz request completes two
specialist cards, Orchestrator synthesis, and one same-thread Scintillate final
response while all six gateways remain healthy.

## Decisions

- Preserve the dirty canonical dotfiles checkout; use this clean worktree.
- Omit per-task skills from Scintillate-to-Orchestrator cards because skill
  names resolve in the assignee profile and the successful control used none.
- Do not retry or mutate the blocked pre-fix card `t_dac0b277`; create a fresh
  post-deployment acceptance request.

## Evidence

- Mac source host: `MacTraitor-Pro.local`, Darwin arm64.
- Pre-fix card `t_dac0b277` crashed before model startup with
  `Unknown skill(s): kanban-board-workflows` and zero children.
- Agents-workspace focused Python and Nix contract checks pass on commit
  `40a20fc`.
- The live Buzz profile configuration included `kanban`, but Hermes checked
  only the legacy root toolset. The landed runtime patch resolves the active
  `HERMES_SESSION_PLATFORM` and preserves legacy root-toolset support.
- Agents-workspace `main` readback equals
  `18aac673811406d579b2c0ec87524b48a1930d7f`.
- Review caught and the landed follow-up fixed explicit-platform precedence,
  platform-sensitive registry caching, and Scintillate's native tool surface.
  Scintillate now receives only `kanban_create` and `kanban_show`; Orchestrator
  and dispatcher workers retain their broader role-appropriate surface.
- The first NUC build failed closed because the newer pin's complete Buzz test
  suite expected patches 09-11 while the deployment overlay stopped at patch 08. The overlay now follows the canonical patch-stack order through 11
  before the model-routing and Kanban patches.
- `nuc-scintillate-runtime-access` stack-overflows on both this worktree and
  untouched dotfiles `c9fe8fd8`, so it is a pre-existing check defect rather
  than evidence against this change. The full NUC system build and the focused
  Buzz runtime, staged runtime, and Hermes package checks pass.
- Final post-rebase `hey nuc-wt build` produced
  `/nix/store/hl09aachvrq3j6jdsk9n97ncrahq2vg7-nixos-system-nuc-26.11.20260714.18b9261`.
- Final focused NUC checks passed: `nuc-buzz-hermes-community-runtime`,
  `nuc-buzz-hermes-staged-runtime`, and `nuc-hermes-v0205-package`.

## Reviews

- Parallel standards and issue-spec reviews found no required source edits;
  both required live deployment and acceptance evidence before completion.
- `hey agent-review plan --active-model-family openai` reached the configured
  heterogeneous ACP reviewer and returned `RUNTIME: Authentication required`.
  The user already authorized this bounded deployment; the exact unavailable
  reviewer is recorded rather than treated as a pass.

## Feedback

- Cross-profile Kanban skill names are profile-local; handoff examples must not
  encourage the caller to attach its own skill inventory to another profile.

## Remaining work

- Land dotfiles, dry-activate, switch, and run the fresh Buzz collaboration
  acceptance.

## Commits

- Agents-workspace: `a020b64` skill-leak regression, `74b8c84` handoff fix,
  `48fa683` platform-toolset regression, `40a20fc` initial Hermes runtime fix,
  `d717a67`/`f70aa4f` bounded-role regressions, `18aac67` bounded runtime fix.
