# Worklog: agent-doc-router

Status: complete

## Objective

Make root `AGENTS.md` a concise router, keep one canonical agent workflow, and define a first-seven-line self-healing documentation contract that agents can discover and maintain.

## Decisions

- Extend the existing `AGENT_WORKFLOW.md`; do not create a competing workflow.
- Keep Matt Pocock skills as the existing pinned flake input; adapt useful routing patterns instead of vendoring copies.
- Keep repository-specific workflow guidance project-local.

## Evidence

- Existing architecture mapped by three independent read-only agents.
- Paul Graham, “Write Simply”: https://paulgraham.com/simply.html
- Matt Pocock setup skill: https://github.com/mattpocock/skills/blob/main/skills/engineering/setup-matt-pocock-skills/SKILL.md
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` rebuilt and activated the Nix-managed agent rule.
- `./bin/hey check --worktree` initially formatted `AGENTS.md`; the immediate rerun passed Darwin evaluation, treefmt, pre-commit hooks, and zunit tests.
- First-seven-line contract smoke test passed for `AGENTS.md`, `AGENT_WORKFLOW.md`, and `docs/README.md`.
- Live `~/.pi/agent/AGENTS.md` contains the rebuilt router-style and documentation-maintenance rule.
- `agent-finish` exposed `test-confidence` scanning dependency tests; a red/green regression now excludes `node_modules`, and all 9 agent-quality tests plus the focused audit pass.
- Final `hey agent-finish --worklog .agents/worklogs/agent-doc-router.md` passed repo quality, 9 agent-quality tests, test-confidence, and inventory drift.
- Rebuilt after the hook-path fix; final `agent-finish` passed all applicable checks.

## Reviews

- Plan gate blocked: `./bin/hey agent-review plan --active-model-family openai --worklog …` and the same command with `--reviewer gemini` both exited 1 at ACP session creation with `Authentication required`. Proceeding with an explicit tooling waiver backed by three independent read-only architecture reviews; landing gate will retry.
- Skill review found two scope mismatches; both were fixed so plan gates, worklogs, and tags apply only to qualifying work.
- Documentation simplifier removed duplication and preserved routing, self-healing, and landing requirements.
- ACP landing review also exited 1 with `Authentication required`. Independent landing review found two issues; workflow order and changed-doc CI coverage were fixed.

## Feedback

- ACP plan and landing review authentication is broken; tracked as `dotfiles-87x8`.
- The failed audit was useful feedback: quality tools must exclude vendored dependency trees or they create false blockers.

## Remaining work

None.

## Commits

- `c7539e0bb feat(agents): add self-healing documentation router`
- `c052c6065 fix(agent-quality): ignore dependency test trees`
- `45abf7fc9 fix(hooks): allow absolute beads ledger paths`
- Final worklog and beads sync commits follow.
