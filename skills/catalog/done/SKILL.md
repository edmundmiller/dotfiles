---
name: done
description: Close an explicit repository task by shaping, landing, publishing, proving, and cleaning it up; also handles narrower commit, publish, and landing-verification requests without exceeding their authority.
---

# Done

Close the current repository task completely while preserving unrelated work.
Invoke for `/done`, bare `done` in an active task, or an explicit request to
land, publish, or verify task changes. Do not treat ordinary completion
language such as “I am done reviewing” as publication authority.

## Authority envelope

A bare `done` authorizes full closeout: shape, validate, integrate, publish,
prove, and clean up. A narrower request authorizes only its named stages. Honor
explicit PR, local-only, no-push, squash, merge, rebase, or fast-forward terms.
Never promote “commit and push,” “publish this branch,” or “verify landing” into
full cleanup.

Repository review rules and protected branches override the direct path.
Otherwise **Default to direct landing** on the actual default branch/bookmark.
Discover the destination and remote from live state; never assume `main` or
`origin` merely from convention.

## Completion invariant

Report `Done` only when:

1. Explicit task revisions are reviewable and repository-declared gates plus
   focused behavioral checks pass.
2. Exact ancestry, per-revision patch equivalence, or aggregate task-range
   patch equivalence proves the task landed on the actual default destination.
3. A writable authoritative remote equals the proved local default tip.
4. The recorded task workspace and owned branches are safely cleaned up.

`Done locally` is terminal only when no remote exists by design or the request
explicitly required local-only closeout. A clean feature workspace, successful
push, merged PR label, or passing build alone is never completion proof.

## Workflow

1. Record `active_directory=$(pwd -P)` before changing directories. Establish
   the explicit task boundary from a receipt, recorded revisions, or a direct
   user statement. Subjects and ancestry position are not task provenance.
2. Capture read-only evidence before mutations:

   ```bash
   python3 "${HOME}/.agents/skills/done/scripts/closeout.py" snapshot \
     --repo "$PWD" --active-directory "$active_directory" \
     ${receipt:+--receipt "$receipt"} >"$snapshot"
   ```

   If no receipt exists, establish provenance and use `hey agent-adopt` before
   the first closeout mutation.

3. Shape only task work. Leave unrelated dirt unstaged. Run repository gates
   plus focused tests. Allow one unambiguous task-caused repair cycle; otherwise
   record `Blocked`.
4. Run `jj root --ignore-working-copy`. Read [jj closeout](./references/jj.md)
   when it succeeds; otherwise read [Git closeout](./references/git.md). Never
   initialize jj during closeout.
5. If direct publication is forbidden or review is required, read the
   [GitHub PR path](./references/github-pr.md). GitHub is the explicit hosted
   provider; unsupported providers require authenticated discoverable tooling
   or a precise blocker.
6. After landing proof, read [receipt, cleanup, and reporting](./references/cleanup.md).

## Finite outcomes

- `Done`: remote landing and cleanup proved; receipt terminal.
- `Done locally`: local-only-by-design landing and cleanup proved; receipt terminal.
- `Landed; cleanup deferred`: remote landing proved, but safe cleanup did not.
- `PR ready; merge pending`: required PR exists but gates remain after bounded waiting.
- `Local only`: publication was expected but unavailable or unauthorized.
- `Blocked`: scope, validation, conflict, identity, policy, or proof is unresolved.

Partial outcomes remain open. On the next invocation, re-read live local and
authoritative state, accept recorded evidence only when it still matches, and
resume at the first unmet stage. A false terminal claim records `false_done`.
