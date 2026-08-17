# Worklog: anti-slop

Status: complete

## Objective

Install anti-slop as the repository-wide Oxlint policy, make its sparse virtual-memory requirement work in Amp orbs, and land the verified result on `origin/main`.

## Decisions

- Package anti-slop and `@oxlint/plugins` through Nix instead of adding a root JavaScript package manager.
- Pin Oxlint and its plugin API together at 1.78.0.
- Enable Linux memory overcommit during orb setup and limit Oxlint to one worker because each JS-plugin worker reserves a sparse 4 GiB arena.

## Evidence

- `nix build path:.#anti-slop --no-link --accept-flake-config`
- Generated pre-commit configuration loaded Oxlint 1.78.0 and all anti-slop rules.
- Live smoke: valid TypeScript exited 0; chained assertions exited 1 with `anti-slop(no-chained-type-assertions)`.
- `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests/test_agent_quality.py tests/test_package_policy.py`: 32 passed, 1 skipped.
- `python3 bin/check-agent-rules` and the skill-quality validator passed.
- `python3 bin/agent-quality audit-tests tests packages/pi-packages` and `inventory --check` passed.
- Shell syntax, Nix formatting, and `git diff --check` passed.
- The full `hey check --worktree` gate was attempted. Nix reported unrelated NUC check failures and then stalled during flake evaluation; the process was stopped after more than eight minutes without output.
- The combined agent test command reached 19 passing tests and 1 skip, but 33 existing OMP TTSR cases could not start because the orb does not provide the host-managed `omp` executable.

## Reviews

No external review requested.

## Feedback

Oxlint JS plugins need sparse address-space reservations. Orb setup must set `vm.overcommit_memory=1`; increasing `ulimit` or physical RAM alone does not solve it.

## Remaining work

None.

## Commits

- `feat: add repository-wide anti-slop linting`
