# Worklog: herdr-overlay-0-7-5-landing

Status: complete

## Objective

Verify that the saved Herdr overlay edits are the intentional v0.7.5 update,
exercise package and live Darwin surfaces, and prove clean remote-equal `main`
without changing the Plannotator branch.

## Decisions

- Treat `bc9a5b062e65fb2eca74988ca07bb757ed9b6a8a` as the candidate task
  revision because it contains exactly the five saved overlay paths and was
  already present on clean local and remote `main` when this run began.
- Make no product edit unless source, package, or live verification finds a
  defect.
- Do not inspect, rebase, update, or remove `codex/plannotator-agent-integrations`.

## Evidence

- `jj root --ignore-working-copy`: no jj repository; use Git workflow.
- Host: `MacTraitor-Pro.local`, Darwin 27.0.0 arm64.
- Initial canonical state: clean `main`, local `main`, `origin/main`, and
  authoritative `refs/heads/main` all at
  `bc9a5b062e65fb2eca74988ca07bb757ed9b6a8a`.
- Candidate commit changes only the five reported Herdr overlay paths.
- Run receipt:
  `/Users/emiller/.local/state/dotfiles-agent-runs/dcdf32527f02/20260729T041618Z-d1795491f576.json`.
- Upstream `v0.7.5` resolves to release commit
  `ef4c23f5775bb8cfec05f05d0844226ff959a07a`.
- Upstream vendored-libghostty commit `4a3302d` contains the former 0010
  `p.before(ap)` guard and the
  `cursor near top pushed to scrollback` regression test, so deleting the
  downstream duplicate is intentional.
- `nix develop .#agent -c pkg-list`: `overlays/herdr` declared.
- `nix develop .#agent -c pkg-check herdr`: all six remaining patches applied
  to fresh upstream `v0.7.5`; declared `nix build --no-link` passed.
- `nix build --no-link --print-out-paths .#herdr`:
  `/nix/store/s470w8aaplq2gnx8sdyl3ggpw70v66qc-herdr-0.7.5`.
- Built binary and flake package version both report `0.7.5`.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .`: exit 0.
- Activated `/etc/profiles/per-user/emiller/bin/herdr` resolves to the same
  Herdr 0.7.5 store path and `herdr --version` reports `herdr 0.7.5`.
- `hey check`: `All Darwin checks passed!`; Darwin configuration, tmux tests,
  package harness tests, package policy tests, and ast-grep tests exercised.
- `hey agent-audit-tests`: `PASS test-confidence`.
- `hey agent-finish --worklog ...`: all required repository and agent-quality
  gates passed; UI and zsh performance surfaces were correctly not applicable.
- Canonical `main` remained clean at `bc9a5b062` after activation.

## Reviews

- Plan review attempted with
  `hey agent-review plan --active-model-family openai`; ACP session creation
  returned `RUNTIME: Authentication required` before producing findings.
  The explicit delegated requirements and narrow validation plan remain
  operative. Landing review will retry.
- Landing review attempted with
  `hey agent-review landing --active-model-family openai`; ACP session creation
  returned the same `RUNTIME: Authentication required` before producing
  findings.
- Manual semantic and path-scope review found the product commit limited to the
  five reported Herdr paths and this run limited to this worklog. No
  Plannotator ref or file is in scope.

## Feedback

The delegated saved-dirt description was stale by task start: another process
had already committed and pushed the exact candidate change. The workflow must
re-read canonical and authoritative remote state before attempting recovery.

## Remaining work

None.

## Commits

- Candidate product revision:
  `bc9a5b062e65fb2eca74988ca07bb757ed9b6a8a` (`chore(herdr): update to 0.7.5`).
