Publish the task's changes to origin/main and deploy that exact revision to the
NUC through GitHub Actions. This invocation authorizes publication and later
activation of that revision. Push-only or no-deploy overrides activation.

Follow repository guidance and docs/runbooks/candidate-ci.md. Preserve unrelated
work, commit task-owned changes with the originating thread, reconcile onto
fetched origin/main, and run affected checks. Submit the exact candidate with
python3 scripts/candidate_ci.py submit --base BASE --sha SHA.

Before ending the submission turn, hand the existing authority to GitHub with
python3 scripts/ship.py request --receipt RECEIPT --base BASE --sha SHA
--thread THREAD_URL --authority APPROVAL_REFERENCE. Add --deploy only when
activation is authorized. Candidate submission alone is not a shipping handoff.
Save the request state, exact base/SHA, original authority and run URL in the
existing receipt. An uncertain dispatch requires readback, never redispatch.

GitHub's Ship workflow records the authority, lands only the exact passing
candidate, and requests deployment only after successful exact-main push CI.
Both gates, latest-attempt checks, normal fast-forward publication, stale-main,
provenance and deployment-lock guards remain mandatory. If main moves, report
the blocked request and reconcile a new candidate within existing authority.
Never substitute a new SHA, bypass a gate, or fall back to direct main push.

Confirm the identified Ship dispatch registered its authorization artifact.
Subscribe to Ship, CI and Deploy NUC completion for reporting. The initial
Ship run captures BASE, not the candidate SHA; subscribe to that captured head
and SHA for later continuations. Preserve the receipt/checkout for verification.
If registration, credentials, run identity, or reporting fails, report that
specific blocker; do not claim a completed handoff. Accepted GitHub work may
continue despite a reporting failure.

Return "Ship request submitted; publication and deployment pending" with the
run URL and observed state. No Orb watcher, polling, wait loop or new Orb is
needed. CI events report progress; they do not supply authority or require the
agent to land or dispatch. Never keep an Orb active just to wait for CI.
After confirmed registration, source-thread archival must not stop authorized
shipping. Archival disables that thread's notifications, not GitHub's request.
Preserve run links and the receipt for later inspection by an authorized owner.
End the turn while GitHub works; claim pause or billing savings only with evidence.

On completion, inspect the saved runs and latest attempts. Verify the active
dotfiles and agents-workspace revisions and basic host services from Deploy NUC
logs, then check affected runtime behavior through authorized access. Report
publication, activation and verification separately. A dispatch or green CI is
not deployment proof. Report unavailable checks separately.

Revoke saved authority with python3 scripts/ship.py revoke --sha SHA, then
cancel any in-flight Ship or Deploy NUC run and inspect actual state. Completed
registration runs cannot be cancelled. A local no-deploy flag cannot revoke
accepted work. Inspect a saved deployment claim before any retry.

Use docs/runbooks/deploy-nuc.md for recovery and explicitly authorized special
deployment options. Missing workflow/credential access is a blocker, not a
reason to provision SSH, reuse an unrelated token, change access policy, or
weaken CI. Do not change live rulesets or this project's saved Ship prompt
without approval. This invocation grants no unrelated deployment or cleanup.
