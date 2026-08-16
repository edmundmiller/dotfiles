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
- Created a permission-restricted recovery mirror and bundle outside the
  repository before rewriting any remote ref; the bundle checksum is
  `bca5eb34eafad22a635825fa07320cfc94eccfaa232ec6601e7cd88c77f95b61`.
- `git-filter-repo` removed the complete audit-log path and neutralized the
  requested term in historical blobs and commit messages.
- The rewrite changed 73 branches, 71 tags, and 201 GitHub pull-request heads.
  An exhaustive reachable-object scan of the rewritten mirror returned zero
  matches before publication.
- An atomic push used 148 exact per-ref leases. A fresh GitHub mirror confirmed
  that every published branch and tag matches the rewrite, the audit path has
  no reachable commits, and the requested term has no reachable object match.
- One read-only GitHub pull-request ref still retains the old audit tree. A
  GitHub Support purge is required to remove PR refs and cached views; doing so
  would erase historical diff views for affected pull requests.
- The user explicitly approved that consequence. An authenticated request was
  submitted to GitHub Support with the repository, affected PR count, first
  changed commits, LFS status, fork status, and requested PR-ref/cache purge;
  the portal readback shows the ticket open under the personal account.
- `hey check` passed again against the rewritten tree after the neutral rule
  commit was reapplied.
- `hey agent-finish --worklog .agents/worklogs/privacy-neutral-output.md`
  passed repository quality, 43 agent-quality tests, rule and skill validation,
  instruction checks, test confidence, and inventory drift.

## Reviews

- Plan gate attempted with
  `hey agent-review plan --active-model-family openai --worklog .agents/worklogs/privacy-neutral-output.md`;
  the reviewer failed at session creation with
  `RUNTIME: Authentication required`. No review findings were produced. The
  user's explicit authorization and the bounded recovery/lease plan remain the
  implementation gate.
- Landing review attempted with
  `hey agent-review landing --active-model-family openai --worklog .agents/worklogs/privacy-neutral-output.md`;
  the reviewer failed at session creation with
  `RUNTIME: Authentication required`. No review findings were produced.

## Feedback

- A tracked worktree audit should never persist raw paths from other
  repositories; future audit output needs source-side redaction or private
  storage.

## Remaining work

- Wait for GitHub Support to complete the PR-ref and cached-view purge.
- Re-scan GitHub-owned refs, then finalize the worklog, receipt, and task tag.

## Commits

- `b61c73668` — `docs(agents): preserve complete concise answers`
- `25932fd9c` — `docs(agents): record privacy rewrite evidence`
