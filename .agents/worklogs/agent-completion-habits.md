# Worklog: agent-completion-habits

Status: active

## Objective

Shared agents complete one evidenced outcome or report one actionable blocker.

Outcome: Shared agents complete one evidenced outcome or report one actionable blocker.
Done when: Shared rules, the autonomous loop skill, Pi goal prompts, canonical documentation, and regression coverage enforce one active outcome through verified landing or one genuine blocker while preserving existing landing safety.
Proof: Focused agent-quality tests, inventory validation, agent-finish, hey check, deployed runtime target inspection, landing review, and final contract/diff audits all pass.

## Decisions

- Reuse the existing durable-goal tools, prompt templates, and `done` skill; add no scheduler, dashboard, coordinator, notification policy, or task store.
- Preserve the dirty-default-checkout gate and clean integration worktree behavior in the `done` skill.

## Evidence

- Verified host: `MacTraitor-Pro.local`, Darwin arm64.
- Verified this Herdr checkout is Git-only (`jj root --ignore-working-copy` reported no jj repository).
- `sem diff` reported no pre-existing semantic changes.
- Agent run receipt: `/Users/emiller/.local/state/dotfiles-agent-runs/bc23fea75425/20260802T180625Z-f5b3e52a96c7.json`.
- Focused assertions verified the shared rule, autonomous-loop skill, both Pi prompts, unchanged `done` landing invariant, and canonical Pi guide.
- `python3 -m unittest tests.test_agent_quality.AgentQualityTests.test_completion_contract_stays_aligned_across_canonical_sources tests.test_agent_quality.AgentQualityTests.test_done_skill_preserves_landing_safety_contract`: 2 tests passed.
- `python3 -m unittest tests/test_agent_quality.py`: 19 tests passed.
- `python3 bin/agent-quality inventory --check`: PASS; generated inventory is current.
- `hey agent-finish --worklog .agents/worklogs/agent-completion-habits.md`: PASS after `nix fmt`; exercised repo-quality, 19 agent-quality tests, confidence checks, and inventory drift checks.
- `hey check`: all Darwin checks passed.
- Raw `darwin-rebuild switch --flake .` built the new generation but exited nonzero during unrelated Homebrew bundle evaluation because the pinned cask DSL rejects VLC's `command_wrapper`; `hey re` hit the same external blocker.
- Direct activation of the generated Home Manager generation completed successfully. Fresh reads verified the new one-outcome contract in `~/.codex/AGENTS.md`, `~/.pi/agent/AGENTS.md`, `~/.claude/CLAUDE.md`, and both Pi goal prompts.
- Final literal audits found `Outcome`, `Done when`, `Proof`, tangent parking, and blocker handling on the canonical rule/skill/prompt surfaces; the `done` skill still contains both landing-safety anchors.
- `sem diff` showed only the shared rule, Pi prompts, Pi guide, autonomous-loop skill, and agent-quality tests plus this worklog; an unrelated formatter-only package harness change was restored.
- `hey agent-audit-tests`: PASS test-confidence.

## Reviews

- Plan review gate attempted with heterogeneous Claude, Gemini, and Cursor ACP reviewers. Claude and Cursor returned `RUNTIME: Authentication required`; the installed Gemini CLI rejected the ACP `acp` argument before initialization. No review findings were produced. This provider-access blocker is recorded per `AGENT_WORKFLOW.md`; implementation proceeds from the user-approved authoritative plan.
- Landing review gate attempted with the default heterogeneous Claude ACP reviewer and returned `RUNTIME: Authentication required`; no findings were produced. The same provider-access blocker as the plan gate remains.

## Feedback

- Parked: the unrelated Homebrew VLC/Inkscape cask DSL mismatch still prevents a zero-exit full system switch; no package declarations or Caskroom metadata were changed.

## Remaining work

Commit, publish, verify remote equality, complete the receipt, and create the required work tag.

## Commits

Planned commit: `feat(agents): enforce evidenced outcome completion`; required tag: `agent-work/agent-completion-habits`.
