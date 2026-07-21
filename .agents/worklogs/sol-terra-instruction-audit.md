# Worklog: sol-terra-instruction-audit

Status: active

## Objective

Review every shared rule and locally owned skill for GPT-5.6 Sol and Terra. Stop only after model-fit findings are recorded, deterministic prose requirements are enforced by executable checks where justified, focused and repository checks pass, and the branch is committed, synchronized, pushed, tagged, and current upstream.

## Decisions

- Treat Sol as the frontier model for hard implementation, debugging, and synthesis; treat Terra as the balanced default for everyday tool-heavy work.
- Audit locally owned instructions, not immutable upstream plugin caches.
- Preserve unrelated edits in the original checkout by working from a clean sibling worktree based on `origin/main`.
- Keep shared instructions capability-based and runtime-neutral; use Sol/Terra names only in model-testing guidance where the distinction is the subject.
- Add a generic skill validator inside `skill-quality`, then wire it into repository tests and changed-file hooks.
- Consolidate duplicated always-on TDD guidance and soften compression language that can reduce answer clarity.

## Evidence

- Source worktree: `/Users/emiller/.config/dotfiles.sol-terra-instructions`, branch `codex/sol-terra-instruction-audit`, based on `origin/main` at `8e900356e3`.
- Host: `MacTraitor-Pro.local`; Darwin 27.0.0 arm64.
- Current deployment: `modules/agents/codex/default.nix` builds `~/.codex/AGENTS.md` from all shared rule files; Codex reads shared skills from `~/.agents/skills/`.
- Inventory: 16 shared rules and 52 locally owned `SKILL.md` files across catalog, project-local, and conditional sources.
- Structural findings: `honcho-integration` is 541 lines and uses Claude-only `allowed-tools`/`AskUserQuestion`; `jj-history-investigation` is 574 lines; the catalog promises a 500-line limit but has no validator.
- Model-fit finding: `skill-quality` hard-codes Claude/Haiku/Sonnet/Opus despite being globally deployed to Codex; Sol/Terra need capability-tier scenarios instead.
- Rule finding: AGENT-05 and AGENT-12 duplicate red/green policy; AGENT-01 says to sacrifice grammar, which can make a balanced model under-explain without improving Sol behavior.
- `python3 -m unittest tests/test_agent_quality.py tests/test_agent_rules.py tests/test_skill_quality_validator.py tests/test_agent_instruction_wiring.py tests/test_agent_response_contract.py`: 32 tests passed.
- `python3 bin/check-agent-rules`: 15 rules, zero findings.
- `python3 skills/catalog/skill-quality/scripts/validate.py --json skills/catalog .agents/skills skills/conditional`: 53 skills, zero findings.
- `python3 bin/agent-quality inventory --check` and `python3 bin/agent-quality audit-tests tests`: passed.
- `nix flake check ./skills --no-build`: passed; only the existing unknown `homeManagerModules` output warning.
- `hey check --worktree`: Darwin evaluation, formatting, pre-commit hooks, tmux, package harness, package policy, and ast-grep passed after attaching the primary checkout's ignored Nix-managed `.pre-commit-config.yaml` symlink.

## Reviews

- Plan gate attempted with `hey agent-review plan --active-model-family openai`; ACPX reached `session/new` then failed with `RUNTIME: Authentication required`. No review findings were available; local implementation proceeded under deterministic tests and the repository workflow.
- Landing gate pending.

## Feedback

- Portable skills need an explicit, machine-checkable compatibility declaration; otherwise runtime-specific tool names silently enter shared catalogs.
- Linked dotfiles worktrees need the ignored Nix-managed `.pre-commit-config.yaml` symlink attached before `hey check --worktree` can exercise formatting and hooks.

## Remaining work

- Inventory and audit current rules and skills.
- Commit instruction changes, sync skill locks, rebuild, land, push, tag, and verify upstream.

## Commits

Pending.
