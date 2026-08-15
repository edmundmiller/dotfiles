# Worklog: privacy-neutral-output

Status: active

## Objective

Keep public agent guidance diagnosis-neutral, add completeness safeguards, and
remove the cross-repository audit log containing private vault paths from every
reachable Git branch and tag. Stop only after the rewritten default branch is
published and the authoritative remote passes a bounded history scan.

## Decisions

- Keep `config/agents/rules/01-tone-and-style.md` as the neutral source of
  truth. Do not install, star, fork, or reference either upstream style project.
- Add only two behavior rules: preserve warnings and exact conditions during
  compression, and suspend brevity when the user explicitly requests depth.
- Purge `.agents/worklogs/audit-agent-worktrees.md` as a complete path rather
  than retain selected private filenames. The audit log is transient evidence,
  not runtime behavior, and contains unrelated cross-repository paths.
- Rewrite all public branches and tags from a fresh mirror clone using
  `git-filter-repo`, after creating a private local recovery bundle.
- Use an exact remote object ID as the force-with-lease expectation and re-read
  repository identity immediately before publication.

## Evidence

- Public repository identity: `edmundmiller/dotfiles`, default branch `main`.
- Local `HEAD` and live `origin/main` initially matched exactly.
- The active neutral rule contains no diagnosis language.
- The tracked audit log is 58,341 bytes and was introduced by one dedicated
  audit-evidence commit.
- GitHub documents `git-filter-repo --sensitive-data-removal --invert-paths`
  as the supported path-purge workflow.
- `git diff --check`, `sem diff`, and `hey agent-worklog-check` passed for the
  scoped source and worklog.
- `hey check --worktree` passed formatting, hooks, Darwin evaluation, tmux,
  package harness, package policy, and ast-grep checks.

## Reviews

- Plan gate attempted with
  `hey agent-review plan --active-model-family openai --worklog .agents/worklogs/privacy-neutral-output.md`;
  the reviewer failed at session creation with
  `RUNTIME: Authentication required`. No review findings were produced. The
  user's explicit authorization and the bounded recovery/lease plan remain the
  implementation gate.
- Landing review: pending.

## Feedback

- A tracked worktree audit should never persist raw paths from other
  repositories; future audit output needs source-side redaction or private
  storage.

## Remaining work

- Create scoped commits and a private recovery bundle.
- Rewrite and publish all affected public refs.
- Verify GitHub readback, record commits, and close the receipt.

## Commits

- Pending.
