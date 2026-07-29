# Worklog: plannotator-agent-integrations

Status: blocked

## Objective

Install a pinned Plannotator binary declaratively and configure Codex, Claude,
Pi, and OMP to expose their supported plan/code-review integrations. Herdr
sessions must inherit the binary and the configured agent integrations.

Stop when focused checks pass, the Darwin configuration is rebuilt, each local
runtime reports the expected integration, and the branch is pushed and equal to
upstream.

## Decisions

- Pin Plannotator OSS v0.25.0, the current stable release on 2026-07-28.
- Pin Pi's extension to v0.24.2, the newest release published before Pi
  0.81.1's package cutoff. OMP can load v0.25.0 directly.
- Use upstream-native integration surfaces: Codex Stop hook, Claude marketplace
  plugin, and the Pi extension for both Pi and OMP.
- Treat Herdr as the workspace owner, not a Plannotator agent harness. It has no
  upstream Plannotator adapter; its launched agents inherit the shared binary
  and their native integrations.
- Preserve existing writable Codex and Claude hooks/plugins through idempotent
  activation merges.

## Evidence

- `hostname`; `uname -a`: MacTraitor-Pro.local, aarch64 Darwin.
- `git fetch origin --prune`: task started clean at `origin/main`
  `c2b411ce3740660145b9b7e7bc0c6e06f60717a4`.
- Upstream installation docs and v0.25.0 release assets/checksums inspected.
- Local baseline: ad-hoc `~/.local/bin/plannotator` v0.25.0 exists, but Codex,
  Claude, Pi, and OMP do not currently report Plannotator integrations.
- Start receipt:
  `/Users/emiller/.local/state/dotfiles-agent-runs/1e6b652d38fd/20260729T025115Z-5324612b9071.json`.
- TDD: `python3 -m unittest tests.test_plannotator_config` failed on the missing
  implementation and Pi-compatible version, then passed with three tests.
- Pi regression: the Nix-copied Mach-O had an invalid signature and the
  inherited launcher bypassed the repaired copy. Two expected-failure test
  commits captured both defects before their fixes.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .`: passed
  after the final Pi-compatible package pin.
- Live Codex: `features.hooks = true`; its `Stop` hook resolves the pinned
  Plannotator 0.25.0 Nix-store binary with timeout 345600.
- Live Claude: marketplace `backnotprop/plannotator`; enabled plugin
  `plannotator@plannotator` v0.25.0.
- Live Pi: signed copied runtime reports 0.81.1; `pi list` installed
  `@plannotator/pi-extension@0.24.2`.
- Live OMP: `plugin doctor --json` reports Plannotator v0.25.0 `status: ok`.
- Live shared state: `plannotator --version` reports 0.25.0; all three
  Plannotator skills resolve under `~/.agents/skills`; Herdr integrations for
  Pi, Claude, and Codex report current.
- Focused Python, Pi, OMP, Ruff, nixfmt, and diff checks passed.
- `hey agent-audit-tests`: `PASS test-confidence`.
- `hey check`: Darwin evaluation, lock sync, tmux, package, policy, and ast-grep
  checks passed. Its formatter/pre-commit wrapper could not discover the
  generated config absent from this worktree; the same hooks were rerun against
  `/nix/store/dl5wyj0jfxdvr7xw0qg9cn9zn2wc9cnz-pre-commit-config.json` across
  every task file and passed.
- `hey agent-finish`: its installed wrapper selected the JSON utility `jj`
  1.9.2 where the bundled test requires Jujutsu, so that unrelated completion
  test failed. The same focused test passed from current source with Jujutsu.
- Done snapshot: canonical `main` has unrelated Herdr overlay edits. The dirty
  default-checkout gate forbids moving or landing `main`; those files remain
  untouched.
- Continuation audit: the same five canonical Herdr files remain dirty and
  `origin/main` still lacks `modules/agents/plannotator/default.nix`.
- A later rebuild from canonical `main` restored Pi's unsigned upstream
  launcher: `pi --version` exited 137 and `.pi-wrapped` referenced
  `/nix/store/pyp1rz...-pi-0.81.1/libexec/pi/pi`.
- Reapplying this feature generation passed. Fresh proof reports signed Pi
  0.81.1 with `@plannotator/pi-extension@0.24.2`, Plannotator 0.25.0, OMP
  doctor `ok` at 0.25.0, Claude 0.25.0 enabled, Codex hooks enabled, all three
  shared skills present, and the Herdr-triggered Plannotator module enabled.

## Reviews

Plan gate attempted with the default Claude reviewer, then OpenCode and Droid
fallbacks. No heterogeneous review completed:

- Claude: `Authentication required`.
- OpenCode: `Internal error: OpenCode service failure`.
- Droid: `Authentication required` (requested device login / `FACTORY_API_KEY`).

This is a medium-risk, local declarative integration. Implementation may
continue with focused tests and live runtime checks; the unresolved review gate
was retried at landing. Claude again returned `Authentication required`.

## Feedback

- Until this change lands on `main`, any canonical rebuild can revert the live
  Pi repair and agent integrations even though the feature generation works.

## Remaining work

- Owner must clean or commit the unrelated canonical Herdr overlay edits. Then
  fast-forward `main`, push it, complete the receipt, and prove remote equality.

## Commits

- `test(pi): capture invalid Darwin signature`
- `fix(pi): re-sign Darwin runtime binary`
- `test(pi): capture copied runtime bypass`
- `fix(pi): launch re-signed runtime copy`
- `feat(agents): configure Plannotator integrations`
