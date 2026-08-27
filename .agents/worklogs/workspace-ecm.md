---
purpose: Record the cross-profile Hermes Kanban repair, deployment, and live acceptance proof.
applies_to: Scintillate, Orchestrator, Kanban workers, Buzz delivery, and the NUC Hermes deployment.
entrypoint: Review the objective, decisions, and final evidence before changing this handoff.
verification: Re-read the landed SHAs, NUC generation, Kanban graph, Buzz relay event, and six gateway units.
update_when: Cross-profile routing, notifier ownership, or the deployed Hermes patch stack changes.
---

# Worklog: workspace-ecm

Status: complete

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
- The fresh LIVE-05 request event
  `68cfe2614c9cf6e632372d6189c5e62ca992c1518ed599819deed5ff40c759f9`
  created root `t_668348e6` and exactly two runnable workers:
  `t_0ad409e5` (Amos) and `t_85c95437` (Anne).
- The workers completed with `AMOS-LIVE-05-OK` and `ANNE-LIVE-05-OK`; the
  root completed with `ORCHESTRATOR-LIVE-05-OK`.
- A deployed profile-identity mismatch initially left the Scintillate
  subscription cursor at event 79. Hermes now prefers `HERMES_PROFILE` over
  the container-local default registry, and the cursor advanced to completion
  event 100 after the corrected gateway restarted.
- Authenticated Buzz relay readback found exactly one non-trigger response with
  `SCINTILLATE-LIVE-05-FINAL-OK`: event
  `0f30cca024f359a9fcda589028660bf9a28875c83ac882148761e80657bf0a9c` in
  the original DM, containing all three upstream markers and task IDs.
- The deployed generation is
  `/nix/store/1fk41385zsfapxx0f4mq1gg5ff1vjp17-nixos-system-nuc-26.11.20260714.18b9261`.
  All six Hermes gateways are loaded, active, running, `Result=success`, and
  `ExecMainStatus=0` with no restarts.

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

## Completion

- Source, deployment, and live acceptance are complete. Beads issue
  `workspace-ecm` is closed with the authenticated relay proof.

## Commits

- Agents-workspace: `a020b64` skill-leak regression, `74b8c84` handoff fix,
  `48fa683` platform-toolset regression, `40a20fc` initial Hermes runtime fix,
  `d717a67`/`f70aa4f` bounded-role regressions, `18aac67` bounded runtime fix.
- Agents-workspace fan-in: `23d061b` regression, `1101383` fix.
- Agents-workspace notifier identity: `20a5b55` regression, `7c427f1` fix;
  issue closeout landed at `3ae5a94562aa785c07f8c5bc1d9ae092d82609b6`.
- Dotfiles deployment: `9a1bcaf30` fan-in guidance, then
  `0a4b5a9c4489d53bedb30712a8eab278068c8f45` profile identity.
