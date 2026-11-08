Publish the task's changes to origin/main and hand off an exact-revision NUC
deployment request to GitHub Actions. This invocation authorizes publication
and the workflow's later activation of that revision. An explicit push-only or
no-deploy instruction overrides activation: submit no deployment request and
report deployment skipped.

Follow repository guidance, preserve unrelated work, run task-scoped checks,
and include approved task-owned repairs. Follow docs/runbooks/candidate-ci.md
for publication. Commit task changes, fetch origin/main, reconcile onto its
exact SHA, and validate the candidate locally. Use
python3 scripts/candidate_ci.py submit --base BASE --sha SHA to publish only
candidate/BASE/SHA. Record the base, candidate SHA, branch, original authority
and CI subscription in the existing receipt. Subscribe to candidate CI
completion and return "Candidate
submitted; main unchanged" rather than watching or polling CI in the Orb.

On the candidate's completion event, recheck current authority and use
python3 scripts/candidate_ci.py land --base BASE --sha SHA. It requires the latest
exact-candidate CI attempt and both required contexts to succeed, then makes
a non-forced fast-forward to the same SHA. Failed, missing, cancelled or
pending checks block publication to main. If main moved, reconcile, rerun
affected checks and submit a new candidate; never reuse old CI for a new SHA.
No mandatory PR, merge commit, force push or admin bypass is part of this route.
An uncertain push requires remote readback before retrying. A bypass warning
means a write may have occurred but compliant landing is unproved; stop and
report it. Do not change the live ruleset or Ship prompt without approval.

Record the exact published revision after landing. Green default CI certifies
affected Linux and portable checks, not native Darwin; Mac activation still
requires native validation of its exact candidate.

Choose the deployment route before SSH preflight. From an Amp orb, use the
existing Deploy NUC GitHub Actions workflow, not direct SSH. Read and follow
docs/runbooks/deploy-nuc.md, section "Ship from an Amp orb". After publication,
use scripts/nuc_shipping.py request with the exact published SHA, existing
receipt, owner thread, and this invocation's deployment authority. The command
submits immediately; it does not require CI to have started or finished.
The workflow owns waiting for successful exact-main CI and the guarded
deployment. Neither a push nor a CI event is itself deployment authorization.

This submission stage ends when the request is accepted, its run is identified,
and completion reporting is established. Return "Published; deployment request
handed to GitHub" without an Orb-side gh run watch, polling loop, background
watcher, or new Orb. Keep the receipt and checkout for result inspection.
Submission is complete; deployment and verification remain pending. Report
observed active/paused intervals when available, not inferred billable savings.

Preserve the pre-dispatch claim and reconcile uncertain results with
nuc_shipping.py reconcile instead of redispatching. The workflow checks
expected_sha against its captured main commit before waiting. Its read-only
wait job checks live main and latest exact-SHA main-push CI, including reruns.
Failure, cancellation, timeout, or moved main stops deployment. The deployment
job repeats the guards before checkout or tailnet enrollment. Keep its
provenance and deployment-lock guards. Never omit expected_sha or replace it
with newer main. If the guarded workflow is unavailable, report that blocker.

Identify the deployment by workflow, requested-SHA title, actor, and dispatch
time, not only captured head SHA. Save its run URL and authorization in the
receipt. Confirm active ci.yml and deploy-nuc.yml reporting subscriptions for
this same owner and the exact head. Inspect already-completed runs immediately.
Missing or ambiguous run identity is a reporting blocker; never choose an
unrelated latest run or submit another request. A subscription failure does
not cancel work already accepted by GitHub. On completion, recheck the saved
run and latest attempt before inspecting logs.
Candidate completion may resume the original authorized landing and handoff;
events confer no new authority, and deployment completion never submits another
request. Dispatch acceptance is not deployment success. Do not provision SSH
credentials, change tailnet access, or create another runner thread to bypass
missing access.

If no-deploy arrives after submission, cancel the identified workflow and verify
its outcome. The local --no-deploy flag cannot revoke an accepted request.
Cancellation during activation may leave a generation active; inspect actual
state before reporting deployment prevented.

Use the private nuc runner when this thread already runs there. Confirm hostname
and uname before direct host operations. Deploy through hey nuc and retain its
clean-source, provenance, stale-source, and deployment-lock guards. Other non-orb
executors may use existing authorized NUC access and the documented hey route;
otherwise use the same GitHub request handoff. Do not grant the shared runner
sudo, copy credentials, or create another runner thread to reach this checkout.

Verify the NUC's active configurationRevision and locked agents-workspace
revision match the exact deployment. For GitHub deployments, use the identified
workflow's revision-verification step and logs without requiring orb SSH.
Inspect SSH/Tailscale services, the disabled auto-upgrade timer, and failed
systemd units. Check affected services and runtime behavior through authorized
access or evidence. Report unavailable task-specific checks separately. A
nonzero switch may still activate a generation; inspect actual state and
distinguish task-caused failures from pre-existing ones. Repair task-caused
failures within scope, validate, publish the repair, and establish a new
exact-revision request. Preserve the previous attempt's evidence. Never
disable guards or change unrelated data to make health checks green.

Report publication, activation, and verification separately, with the deployment
run URL and any blockers. Keep the task open until authorized deployment,
required verification, and safe cleanup are proved. This workflow does not
authorize secret rotation, new access grants, destructive cleanup, unrelated
repairs, or unrelated releases.
