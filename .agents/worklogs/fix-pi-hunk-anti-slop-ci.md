# Worklog: fix-pi-hunk-anti-slop-ci

Status: complete

## Objective

Repair the pre-existing Pi Hunk anti-slop failure that blocked Linux and Darwin
CI for the already-landed coding-agent test-quality change. Stop only after the
repair preserves the Pi tool-response contract, focused and repository checks
pass, an independent review is closed, the repair is landed separately on
`main`, and GitHub's Linux and Darwin checks pass.

## Decisions

- Keep this repair separate from `feat(agents): enforce meaningful test
coverage` and preserve that landed commit unchanged.
- Fix the unsafe runtime parsing at its Herdr JSON boundaries instead of
  refreshing suppressions for real violations.
- Preserve unrelated work in the dirty primary checkout; use only the isolated
  `coding-standards-review` worktree.
- Make the existing Pi Hunk test suite part of package QA so the new boundary
  regressions cannot be silently skipped.

## Evidence

- Starting revision: `17965063eba6b0239cd3928b626e9a79659391f8`, matching
  the authoritative `origin/main` before this repair.
- GitHub run `33293362732` and four earlier `main` runs reproduced the same
  pre-existing anti-slop failures in `pi-hunk/extensions/hunk.ts`.
- `./bin/qa-changed --package pi-hunk` passes typecheck and eight Bun tests
  with 19 expectations, including context fallback, malformed requested values,
  malformed unrelated siblings, parsed details, JSON strings, and empty output.
- Full-repository Oxlint passes after pruning the repaired Hunk entry and four
  independently stale Pi Beads suppression entries.
- `hey check --worktree` passes Darwin evaluation, changed-file formatting and
  hooks, tmux, package harness/policy, DJI Mic Mini, and ast-grep checks.
- The exact Darwin pre-commit derivation reaches green Oxlint and every other
  source hook; its sole local failure is `skills-lock-sync` because this host's
  Nix daemon rejects nested access from `_nixbld` users. The hook passes
  directly as the repository user and passed in GitHub's Darwin runner.
- The exact Linux derivation cannot execute locally because this ARM Darwin
  host has no `x86_64-linux` builder. GitHub's native Darwin and Linux jobs are
  therefore the required parity proof.

## Reviews

- Initial independent review found response compatibility regressions in JSON
  formatting, `details.parsed`, and whole-object validation. All were fixed.
- Fresh final review found no P1/P2 issues and confirmed behavior compatibility,
  requested-field/path validation, test routing, and suppression scope.

## Feedback

- A focused per-file lint does not detect stale entries elsewhere in the shared
  Oxlint suppression file; run the repository-wide hook after pruning.

## Remaining work

- No implementation work remains. Closeout must commit and publish the repair,
  wait for GitHub's Darwin and Linux proof, complete the receipt, and remove the
  isolated worktree and branch.

## Commits

The separate repair commit hash will be reported in the final handoff.
