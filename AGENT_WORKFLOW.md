---
purpose: Define completion and handoff for substantial agent-authored changes.
applies_to: Multi-session, high-risk, or explicitly workflow-guided dotfiles work.
entrypoint: Establish the intended result and the authority needed to reach it.
verification: hey check, with focused runtime checks where relevant.
update_when: Shared completion, handoff, or approval boundaries change.
---

# Agent workflow

Carry the requested outcome through implementation and proportionate verification,
not merely a plan or intermediate patch. Continue safe local work without
repeated approval; stop at consequential ambiguity or an unauthorized external
action, with the reviewable work and exact next action ready.

## Completion

Implementers and reviewers use the same acceptance criteria from the existing
request, issue, spec, or goal. Do not create a second tracking system. Verify
observable behavior on the current revision; green checks alone are insufficient
if they do not exercise those criteria. For defects, reproduce the failure before
the fix when feasible, then repeat the check afterward. Label static review,
simulated checks, and actual runtime evidence separately.

Run `hey check`; it selects formatting, lint, and affected test suites. Use
task-owned path arguments in a shared dirty checkout. Add behavior-level checks
not covered by that routing; do not repeat checks already run. Read-only work
needs no validation gate, and unchanged evidence needs no rerun merely to stop.
After an input changes, rerun its affected checks. Report unavailable or unrelated
failures as limitations, not passes or obligations to repair others' work.
See [validation](docs/validation.md) for full and platform-only checks.

For commits or PRs, inspect the staged diff (`git diff --cached`) or committed
tree (`git show HEAD:<file>`). `git checkout <ref> -- <paths>` stages paths;
later edits stay unstaged. Working-tree evidence alone does not verify a commit.

Update documentation when its ownership, commands, or recovery contract changes.
The [guardrails](docs/agent-guardrails.md) define source ownership and approval
boundaries. Commit, publish, deploy, or clean up only within the user's request;
publication and host activation are not implied by completing local edits.

For authorized NUC shipping, follow the request handoff in
[NUC shipping](docs/runbooks/deploy-nuc.md#ship-from-an-amp-orb). GitHub owns CI
waiting and deployment after the agent submits the authorized exact revision.
Persist the request, authority, run URL, and reporting subscriptions in the
existing receipt. Submission ends after handoff; deployment remains pending.
Keep that receipt and checkout until deployment evidence and cleanup are
complete. A completion event resumes result inspection by the same owner;
it does not authorize new changes or another deployment.

Cross-model review is optional and runs only on explicit request. It is not a
quality gate. `hey check` never applies repairs to source; use `nix fmt` for
intentional formatting. Model-driven repairs are explicit agent work.

## Durable handoff when needed

Before a handoff or session limit, update the existing issue, goal, or worklog
with a concise checkpoint: revision and checkout, acceptance criteria, decisions
and relevant rejected approaches, remaining authority, evidence and limitations,
blockers, and next owner/action. Mark uncommitted changes explicitly. The receiver
inspects the referenced sources and current code before continuing; address review
findings with a fix, reasoned rejection, or explicit blocker.

Checkpoints are optional for small work that does not cross sessions.
`.agents/worklogs/TEMPLATE.md` and `hey agent-start` are optional aids, not new
requirements. If Herdr already created the current jj task workspace,
record it rather than creating another one. Creating a receipt or checkpoint
does not authorize commits, tags, publication, cleanup, or deployment.

`hey agent-sweep --json` inspects existing receipts; a weekly launchd job also
sweeps them. Repeated friction belongs in the smallest owning rule, skill, or
tool, rather than another parallel checklist.
