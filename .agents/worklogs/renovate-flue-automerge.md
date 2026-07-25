---
purpose: Track the agent-assisted Renovate patch repair and automerge rollout.
applies_to: Herdr and Hunk Renovate update automation.
entrypoint: .github/workflows/renovate-patch-repair.yml
verification: Validate Renovate extraction, workflow policy, path guards, package checks, and repository auto-merge.
update_when: The workflow, Flue agent, patch allowlist, or required checks change.
---

# Worklog: renovate-flue-automerge

Status: active

## Objective

Herdr and Hunk release PRs are opened by Renovate, repaired by Flue only when the fresh-source patch check fails, and merged by GitHub only after required checks pass. Stop when the workflow is source-validated, the deterministic guards are tested, focused package checks pass, repository auto-merge is enabled, and the landed branch equals upstream.

## Decisions

- Use `pull_request_target` only for same-repository `renovate/herdr` and `renovate/hunk` branches carrying `flue-review` whose PR author matches `RENOVATE_LOGIN`.
- Give Flue a `git archive` snapshot in an isolated Docker container. It has no `.git` directory, GitHub token, or model credential. All PR-controlled Nix execution stays in no-secret containers.
- Expose `RENOVATE_TOKEN` only to deterministic push and automerge steps. The host Flue runtime holds `OPENROUTER_API_KEY`; model shell commands run inside the container.
- Validate changed paths and manifests before model access and after importing model edits with trusted scripts copied from the base commit.
- Import only patch files. Derive patch manifests deterministically while preserving Renovate-owned source pins, hashes, and lockfiles.
- Run the base revision's trusted `pkg-check` tooling against the PR snapshot before invoking Flue and again against a fresh imported snapshot; successful deterministic updates spend no model tokens.
- Use `openrouter/anthropic/claude-sonnet-4.6`, overridable through `FLUE_MODEL`.
- Keep Renovate automerge disabled. The workflow enables platform automerge only after `pkg-check` succeeds; GitHub required checks remain the final merge authority.

## Evidence

- GitHub ruleset requires `Flake Check (Linux)` and `Check Formatting`; repository auto-merge was disabled during research.
- Repository Actions secrets contained only `NPM_TOKEN`; live automation needs dedicated `RENOVATE_TOKEN` and `OPENROUTER_API_KEY` secrets.
- Renovate documents fine-grained PAT support with repository-scoped Contents, Issues, Pull requests, Workflows, and Commit statuses access. A GitHub App remains preferable if this expands beyond one repository.
- Flue `1.0.0-beta.9` builds and reaches the pinned `openrouter/anthropic/claude-sonnet-4.6` provider through the Docker-backed sandbox. The model command process cannot inherit host credentials.
- Renovate strict validation and extraction found both Herdr manifests plus the Hunk manifest in a temporary Git checkout containing the new files.
- The new Herdr fresh-source harness exposed a malformed `0009-defer-background-tab-resize.patch`. Regenerating that patch against `v0.7.4` and deleting its dead resize helpers restored package application and build.
- `pkg-check herdr`, `pkg-check hunk`, `nix build --no-link .#herdr`, the 42 targeted Herdr background-resize tests, package-policy tests, Flue build, Docker adapter smoke, and Actionlint passed.
- `hey check`, `hey agent-audit-tests`, explicit Treefmt, package-policy tests, Renovate strict validation, and both workflow Actionlint checks pass in the staged tree.
- The repository `RENOVATE_LOGIN` variable is deployed as `edmundmiller` and was re-read from GitHub.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` built and activated the staged Darwin configuration.

## Reviews

- Plan gate attempts with Claude and OpenCode failed before producing findings (`Authentication required`; `OpenCode service failure`). This is the repository's known ACP review blocker. Proceeding with source-backed design, focused security tests, and a landing-gate retry.
- The code-simplifier reduced the path guard. Its TypeScript parameter-property rewrite was reverted after the direct Node sandbox smoke exposed incompatibility with strip-only execution.
- Silent-failure and type-design reviewer agents failed before review because no model was selected. Inline review confirmed that every model, import, validation, push, and auto-merge failure leaves the job failed and prevents merge.
- Landing review found two trust-boundary gaps before publish: host execution of PR Nix and PR-controlled validation tooling. The workflow now mounts a read-only base archive, runs its `pkg-check` inside no-secret containers, and rejects package-harness `source` or `checks` drift before execution.
- Landing review also found a validation/import race. The second container now mounts the derived validation snapshot read-only, so the bytes imported after success are exactly the bytes checked.
- The required heterogeneous landing retry still failed before review because the Claude ACP route requires authentication.
- Final review caught the default dev shell's pre-commit hook mutation. Both container checks now use the trusted `#agent` shell; `nix develop .#agent --command pkg-check herdr` passes.

## Feedback

- Nix flake checks exclude untracked files. Stage only task-owned new files before `hey check`; otherwise the derivation reports misleading command-not-found failures.
- `hey agent-finish` passed worklog and repository quality but its Nix-built agent-quality suite failed when `jj git init --colocate /tmp/...` could not see the just-created Git repository. The exact focused test passes directly outside the Nix sandbox.

## Remaining work

Finish fresh verification, land the task-only files, configure both repository secrets, enable repository auto-merge, and verify remote equality.

## Commits

Pending.
