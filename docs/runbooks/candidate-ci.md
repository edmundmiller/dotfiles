---
purpose: Publish task changes to main after local checks and deploy only green main revisions.
applies_to: Authorized dotfiles publication, main CI and the publishing-policy cutover.
entrypoint: Run affected hey check paths, reconcile onto origin/main and push normally.
verification: Verify remote publication, exact-SHA main CI and separate NUC rollout readback.
update_when: Publication authority, main protection, CI selection or rollout gates change.
---

# Main-first publication

The filename is retained for existing links and the separate Renovate candidate pilot. Routine task publication does not use candidate branches or the former Ship controller.

## Publish

With explicit publication authority:

1. Preserve unrelated changes. Fetch `origin/main` and reconcile only the task's commits onto it. Inspect the resulting diff.
2. Run `hey check` on the task-owned paths and the focused checks needed for the change. Fix local failures. A changed shared Nix input can still select broad checks; do not suppress that selection to make publication faster. Host builds, Darwin and service VMs remain explicit platform validation, not mandatory publication gates for unrelated work.
3. Commit with the originating Amp thread, inspect the committed diff and push normally with `git push origin HEAD:main`. Verify the remote commit. If another writer wins the race, fetch, reconcile and rerun affected checks before another normal push. Never force or bypass a live rule. An uncertain push requires readback before retrying.
4. Subscribe to `ci.yml` for the exact published SHA and retain its run URL. Report publication immediately, with CI pending if it is still running. Do not keep an Orb active to wait for it.

There is no agent candidate branch, exact-base request, automatic replay lineage or cross-task publication slot. No PR is required unless explicitly requested. Ordinary concurrent Git pushes arbitrate publication. Temporary cutover coordination still applies to work already queued under the old policy.

Main CI may fail. Inspect its latest attempt and fix task-caused failures forward on main within existing publication authority. A new fix gets its own local checks and ordinary main CI. Report unrelated failures rather than silently changing unrelated work. Do not erase published commits, reuse old SHA attestations or disable checks to manufacture a green release.

## Publication and activation

Publication is a verified main push. NUC activation is a separate outcome with its own authority and host evidence. A publication-only task finishes at verified landing without host access; its main-CI result still needs reporting and task-caused failures still need repair.

When separately enabled with `NUC_ROLLOUT=continuous`, [continuous rollout](deploy-nuc.md#continuous-rollout) selects the newest eligible published main revision whose latest main-push CI passed. If the head is red or pending, that head cannot deploy. An older green descendant of the active revision can deploy instead. A failed rollout does not block publication; fix forward, then let a newer green revision become eligible.

The exact target, pinned build, host lock, ancestry/no-downgrade checks, provenance readback and service health remain mandatory. Report the actual active revision, not merely the newest pushed SHA. Standing authority permits combined revisions; an old task's exact-deployment approval does not. Setting or pausing rollout is a separate repository-settings action.

For push-only/no-deploy work, every task commit needs `NUC-Rollout: publication-only` before publication. It does not trigger activation by itself, but later eligible rollouts can include it. `NUC-Rollout: hold` is the stronger stop before a commit; resuming past it requires an explicitly approved exact deployment. Neither trailer removes commits from main or from future host configurations.

If rollout is disabled, leave it disabled. A separately authorized [manual exact deployment](deploy-nuc.md#manual-exact-main-requests-and-special-deployment-options) remains available. Its exact-main and CI guards are not permission to substitute a later revision. An uncertain deployment dispatch requires readback, not another dispatch.

Subscribe to exact-SHA main CI for publication reporting. Use a standing Deploy NUC listener only when one is configured; the current [rollout reporting gap](deploy-nuc.md#continuous-rollout) must be reported rather than hidden behind finite exact-SHA follow-ups. GitHub handles rollout independently of an Orb or source-thread archival. Missing reporting is a named limitation, not evidence of activation. Editing `.agents/ship.md` never updates the saved Amp prompt by itself.

## Approved cutover required

The live main ruleset can still require pre-push statuses. This source change alone cannot make a direct push legal. Until the cutover is approved and completed, publish this migration through the existing exact-candidate path, not a direct-main probe:

```bash
python3 scripts/candidate_ci.py submit --base BASE --sha SHA
# After the latest candidate CI attempt and both contexts pass:
python3 scripts/candidate_ci.py land --base BASE --sha SHA
```

These commands require publication approval and exact 40-character IDs. A moved base requires reconciliation and fresh affected checks; never use force or bypass. Do not start a new legacy Ship request for this migration.

The approved administrator cutover is:

1. Coordinate with owners of existing accepted Ship requests. Let them finish or obtain explicit revocation and cancellation authority before removing their controller. Retain old receipts, refs, artifacts and run links; this change does not revoke accepted authority or delete evidence. Do not translate exact approvals into standing deployment authority.
2. Land this migration through the existing passing-candidate route. The removed workflow no longer accepts new requests; already accepted or running work must have been settled first.
3. Read and save the full live ruleset `14372116`, `Protect main`. Remove only its `required_status_checks` rule so main publication no longer waits for hosted CI. Preserve active enforcement, the exact main target, `non_fast_forward`, an empty bypass list and any unrelated current rules. Do not add PR requirements or a blanket bypass. Read the full ruleset back. This is an explicit approval to change publication policy, not a weakening of the CI gate before host activation.
4. With separate Amp-settings approval, replace the saved Ship prompt with `.agents/ship.md`. Leave tokens, access policy and rollout settings unchanged. Confirm the standing rollout listener is reporting, or name the reporting blocker.

No live setting changes happen merely by landing the code. If access to rules or saved prompts is unavailable, report the specific blocker. Do not provision a new credential or use an unrelated token. Existing queued tasks retain their current ordering until their owners coordinate the cutover; this policy does not rearrange accepted requests.

To recover code, publish a checked fix or revert as a new main commit. Pausing rollout and changing main protection require their own authorization. Never reset main backward.

## CI selection and platform checks

Main push CI uses the previous main SHA as `VALIDATION_BASE`. PR CI uses the PR base. Both run the existing affected-path formatting, lint, tests and package checks. `Flake Check (Linux)` and `Check Formatting` remain stable reporting names for the same aggregate gate, including every explicitly selected platform job. Missing, failed, cancelled or unexpectedly skipped jobs fail the gate. These results gate deployment, not routine task publication after cutover.

Native Darwin and service VMs stay opt-in. Run affected native validation before activating that platform. Portable green does not certify a Mac system, a service VM, host runtime health or hosted-skill delivery. Earlier results never certify a rewritten revision.

## Renovate candidate pilot

The [types-only Renovate pilot](renovate.md#types-only-candidate-pilot) retains its independent, unattended candidate admission. It still uses `candidate/BASE/SHA`, `scripts/candidate_ci.py` and exact successful latest-attempt checks before a normal fast-forward. This exception is not the route for agent task publication and grants no general bot automerge authority. No existing dependency PR is merged, closed or rearranged by this change.

Candidate CI keeps its encoded base planner so a newly created bot branch does not accidentally select the whole repository from GitHub's zero before-SHA. Private-input isolation and the existing optional candidate-output transport remain unchanged.

### Output and dependency reuse

Only the latest successful exact candidate run and attempt can seed its corresponding main validation. `scripts/ci_check_cache.py` accepts only canonical empty, nonexecutable outputs with no references. No source, derivation contents, private dependency closures, credentials or logs may enter that public artifact. Main still computes the current derivations and runs its ordinary validation. An imported exact derivation output is a cache hit, not a transferable green-SHA attestation. A cache miss or malformed artifact never makes validation pass.

The public HA cache in `scripts/ci_dependency_cache.py` remains public-dependencies-only. It evaluates the public nixpkgs-hass pin and HA overlay in isolation, never the private flake or host configuration. Only realized public packages and their runtime dependencies are exported. PRs do not restore or save it, but fork users can read main caches, so a workflow condition is not a confidentiality boundary. Never export a whole store or widen the allowlist to private inputs, test outputs or host data.

The cache key still includes OS, lock file and the public HA overlay, with no broad restore prefixes. The optional exact-candidate artifact can seed main's cache for the Renovate path. Missing, expired or unavailable archives fall back to ordinary validation. Credentials, cache visibility and hosted storage limits do not change. Keep the existing strict format checks and bump cache versions when changing their formats. Measure hosted transfer and build time before claiming a speedup.
