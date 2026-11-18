Publish the task's changes to origin/main through GitHub Actions. This invocation
authorizes up to three conflict-free replays of the task onto newer descendant
main, fresh checks on every resulting SHA, and NUC deployment of the exact landed
SHA after main CI. Deployment includes newer main plus the replayed task changes.
Push-only or no-deploy overrides activation. Stop on conflicts or failed checks.

Follow repository guidance and docs/runbooks/candidate-ci.md. Preserve unrelated
work, commit task-owned changes with the originating thread, reconcile onto
fetched origin/main, and run affected checks. Submit the exact candidate with
python3 scripts/candidate_ci.py submit --base BASE --sha SHA.

Before ending the submission turn, hand the existing authority to GitHub with
python3 scripts/ship.py request --receipt RECEIPT --base BASE --sha SHA
--thread THREAD_URL --authority APPROVAL_REFERENCE --allow-clean-rebase.
Add both --deploy and --deploy-rebased only when activation is authorized.
Carry any required native validation with --darwin and/or --services-vm so each
successor gets fresh hosted evidence. Candidate submission alone is not a shipping handoff.
Save the request state, exact base/SHA, original authority and run URL in the
existing receipt. An uncertain dispatch requires readback, never redispatch.

GitHub's Ship workflow records the authority, lands only the exact passing
candidate, and requests deployment only after successful exact-main push CI.
Both gates, latest-attempt checks, normal fast-forward publication, stale-main,
provenance and deployment-lock guards remain mandatory. GitHub records each
successor before publishing its candidate ref. Existing exact-only requests never
gain rebase authority. Once a SHA lands, later main movement stops deployment.
Only an authorized, freshly checked successor may replace the original SHA.
Never bypass a gate or fall back to direct main push.

Confirm the identified Ship dispatch registered its authorization artifact.
Subscribe to Ship and CI completion for reporting, plus Deploy NUC when activation is authorized. The initial
Ship run captures main at dispatch, which can differ from BASE; subscribe to that
captured head and retain successor SHA/run links for later continuations.
Preserve the receipt/checkout for verification.
If registration, credentials, run identity, or reporting fails, report that
specific blocker; do not claim a completed handoff. Accepted GitHub work may
continue despite a reporting failure.

Report the run URL, observed state and whether the request is publication-only or includes activation. No Orb watcher, polling, wait loop or new Orb is
needed. CI events report progress; they do not supply authority or require the
agent to land or dispatch. Never keep an Orb active just to wait for CI.
After confirmed registration, source-thread archival must not stop authorized
shipping. Archival disables that thread's notifications, not GitHub's request.
Preserve run links and the receipt for later inspection by an authorized owner.
End the turn while GitHub works; claim pause or billing savings only with evidence.

On completion, inspect the saved runs and latest attempts and verify exact publication. Publication-only requests finish at verified landing without host access or runtime readback. For authorized activation, verify the active
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
