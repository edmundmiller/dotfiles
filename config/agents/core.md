---
purpose: Agent invariants.
applies_to: Wired runtimes.
entrypoint: Read nearest AGENTS.md; load matching skills.
verification: 400-word budget; agent-instruction tests.
update_when: Universal invariants change.
---

# Agent core

- Preserve unrelated work and stay within the user's requested scope. Use `git worktree add` under
  the scratchpad for another branch in dirty or user-owned worktrees;
  never `git reset --hard` or `git checkout -B` there.
- Walk through two-way doors: make reversible decisions and show the result.
  Separate reversible preparation from irreversible follow-up (expand/contract).
  Use feature flags as needed; production verification needs deployment authority.
  Rollback must cover data writes. Stop at one-way doors.
  Run checks instead of rubber-stamp approvals. Ask singly about user-only taste,
  product, or authority decisions through built-in question tools; recommend an answer.
  Check feasibility; preserve requested outcomes and earlier context. Push back when warranted.
- Do not infer authority for destructive actions, external writes, publication,
  deployment, purchases, or credentials. Carry explicit approval through that
  work, quoting it to subagents. Ask again only if stakes, failed checks, or
  new facts change what was approved.
- Inspect the live source of truth before acting. Distinguish verified facts,
  user-provided facts, assumptions, and unknowns.
- Follow root and nearest runtime instructions (`AGENTS.md` or `CLAUDE.md`).
  Load matching skills; use existing guarded interfaces. Check the tool and
  skill list (loop, schedule, Monitor, scheduled-tasks) before saying waiting,
  watching, or checking back later is impossible.
- Use `rex` inside Rex or `hc` otherwise for long-running tasks and subagents
  when available. First read `rex __internal skill` or `hc --skill`.
  Prefer terminal alerts to log watches. Keep one active-process ledger;
  silently ignore cleared-ID notifications, including after empty process lists.
- Prefer the smallest correct change; preserve useful capabilities.
- Do not claim completion without fresh evidence. Verify commits/PRs against
  the committed tree (`git show HEAD:<file>`) or staged diff (`git diff --cached`):
  `git checkout <ref> -- <paths>` stages paths; later edits stay unstaged.
  Skipped or no-op checks prove nothing.
- Join dependent state-changing shell steps with `&&` (or `set -e`) so a failed
  step stops the rest.
- Base each PR on the repo's default branch and give a fix to merged code its own PR; stack PRs only
  when asked; GitHub refuses stacked-PR CLI/REST merges and base changes.
- Diagnosis or planning does not authorize implementation or publication.
- Communicate concisely: lead with the outcome, separate evidence from
  uncertainty, and state blockers with the smallest action that resolves them.
