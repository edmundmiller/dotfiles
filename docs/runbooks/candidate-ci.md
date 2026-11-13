---
purpose: Admit the exact hosted-CI-tested commit to main without mandatory PRs.
applies_to: Authorized dotfiles publication and main ruleset rollout.
entrypoint: python3 scripts/candidate_ci.py submit --base BASE --sha SHA
verification: python3 -m unittest tests.test_candidate_ci tests.test_ci_check_cache tests.test_validation
update_when: Candidate refs, required contexts, publication, or live policy changes.
---

# Candidate CI before main

Publication authority is required before submitting a candidate branch or
advancing main. Implementation and local testing authorize neither operation.
Deployment and live settings changes need their own explicit approval.

## Publication contract

1. Commit task-owned work, fetch `origin/main`, reconcile onto its exact base,
   and run affected local checks. Include the originating Amp thread in the
   commit record. Keep the candidate checkout clean and retain its existing
   receipt. Do not create a merge commit just to land it.
2. With publication authorized, run
   `python3 scripts/candidate_ci.py submit --base BASE --sha SHA`, replacing
   both values with exact 40-character commit IDs. This pushes only
   `candidate/BASE/SHA`; it does not update main. The helper requires HEAD to
   equal SHA, BASE to be its ancestor, and remote main to equal BASE.
3. Record BASE, SHA, branch, original authority and the CI run in the existing
   receipt. Subscribe to push CI for that SHA and candidate branch. End the
   submission stage with "Candidate submitted; main unchanged". A subscription
   or lookup failure does not undo a branch push; inspect it before retrying.
   Do not poll CI or keep an Orb watcher running.
4. On completion, recheck authority and run
   `python3 scripts/candidate_ci.py land --base BASE --sha SHA`. This checks the
   latest candidate push run of `ci.yml`, its exact SHA/branch and latest attempt,
   and both required contexts in that attempt. Missing, failed, cancelled,
   skipped or pending results block main. The helper pins GitHub API reads to
   `github.com` instead of inheriting an unrelated `GH_HOST`.
5. Landing is a normal, non-forced Git push of SHA to main, followed by remote
   readback. There is no PR, squash, merge commit, or rewritten candidate. If
   another unrelated commit wins the race, Git rejects the push. Reconcile onto
   new main, run affected checks, and submit a new candidate. Old CI does not
   certify a new SHA. A successful push with a bypass warning is reported as
   noncompliant publication, never as a clean landing.

An interrupted push can have succeeded. Inspect the exact remote refs before
retrying. If main already equals SHA, verify the saved candidate run and record
publication rather than pushing again. Retain candidate refs while evidence is
needed; this helper does not delete remote branches.

## Small admission suite

Candidates use the same changed-path portable/Linux selection as main, with
affected formatting/lint, repository tests and package checks. A small planner
validates the candidate ref and passes its explicit BASE to both Linux and the
affected Herdr VM. A new candidate branch's zero `before` SHA must not turn a
docs change into a full repository run. Shared Nix inputs still select broad
checks deliberately; "small" is not a fixed list that omits affected consumers.

The existing `Flake Check (Linux)` and `Check Formatting` contexts both aggregate
successful planning, Linux, and every selected platform job. They are compatibility
names for one logical gate, not two independent full-suite certifications.
Failures and unexpected skips remain fail-closed. No required-context rename
or new duplicate test list is part of this rollout.

Native Darwin and service VMs remain opt-in. Mac activation still requires the
exact candidate's native Darwin checks, including forced `system.drvPath`
evaluation. A portable green does not prove a Mac build, service VM, or runtime
activation. Run affected target checks before activating that target.

Main-push CI remains enabled. Authorized NUC deployment still waits in GitHub
for the latest successful exact-main push run and retains the SHA, stale-main,
provenance and deployment-lock guards. Candidate success cannot substitute for
that main-push run. This conservatively retains post-main validation work; it
does not claim to eliminate all duplicate builds or prove lower hosted cost.
Use the existing [NUC handoff](deploy-nuc.md#ship-from-an-amp-orb) only when
deployment is authorized. Hosted skill publication still needs served-artifact
parity; host activation is not hosted-skill delivery evidence.

## Candidate output reuse

Linux candidate validation optionally exports its successful portable Nix check
outputs to a three-day run artifact. Main still runs the same selector, hooks,
package tests and `nix build` commands. Before validation, it imports outputs
only from the latest successful exact `candidate/BASE/SHA` push run of `ci.yml`,
with both required contexts successful in that attempt. Artifacts are bound to
that run, SHA and attempt, not searched by name across PRs or workflows. Only
candidate pushes publish; PRs neither publish nor consume this handoff.

GitHub's ordinary branch caches cannot flow from candidate branches to main.
Its public-repository caches and artifacts are readable by other users, so
neither a whole-store cache nor an unrestricted closure artifact is safe for
our private `tnote`, `agents-workspace` and Rex inputs. The existing Security
workflow's magic-cache configuration is not a candidate-to-main solution.

`scripts/ci_check_cache.py` accepts only empty nonexecutable files or empty
directories with no store references. It compares each complete Nix export to
the canonical empty encoding, including metadata. Only public check names and
their store/deriver hashes leave the runner. No source, derivation contents,
dependency closures, logs, netrc files or credentials enter the artifact.
Nonempty outputs such as the callstack package are deliberately excluded.
The standard read-only Actions token downloads artifacts; existing private-input
credentials and repository settings do not change.

Nix still computes the current derivation. An imported exact output is a cache
hit, not a separate check-skipping rule. Different outputs build normally.
Missing, expired, malformed or unavailable artifacts fall back to ordinary
validation. No cache result can make a failed validation pass. A Nix export
format change also causes a cache miss rather than publishing unknown bytes.
Herdr VM, Darwin and service VM jobs retain their existing behavior.

For hosted evidence, retain the candidate's `Check cache: exported` count,
main's `Check cache: imported` count and source run URL, and both jobs' timed
validation logs at the identical SHA. Confirm cacheable checks do not rebuild,
noncacheable work still runs, and both required contexts pass. Local fixture
timings are not a hosted speedup claim. Publishing the candidate and landing
its exact green SHA require explicit publication approval; no deployment or
settings changes are needed. Roll back through a normal candidate revert.

## Live changes requiring separate approval

The helper is not a security boundary. GitHub must reject unchecked main writes
even when a caller skips the helper. After approval, an administrator should
update existing ruleset `14372116`, `Protect main`, without deleting it:

- Keep active enforcement, the exact `refs/heads/main` target, and the
  `non_fast_forward` rule. Do not require pull requests or reviews.
- Keep `Flake Check (Linux)` and `Check Formatting` required. Bind each to
  GitHub Actions integration ID `15368`, verified from this repository's check
  runs, rather than accepting a same-name status from another integration.
- Remove the always-on RepositoryRole bypass. Desired `bypass_actors` is `[]`.
  Do not replace it with another blanket bypass. Keep repository push access
  restricted to the existing authorized writers; no access grant is needed.
- Keep `do_not_enforce_on_create: false` and
  `strict_required_status_checks_policy: false`. The helper checks the exact
  base and ancestry; this rollout does not add PR update-branch semantics.

The required-status rule's reviewed replacement parameters are:

```json
{
  "do_not_enforce_on_create": false,
  "strict_required_status_checks_policy": false,
  "required_status_checks": [
    { "context": "Flake Check (Linux)", "integration_id": 15368 },
    { "context": "Check Formatting", "integration_id": 15368 }
  ]
}
```

Read the complete live ruleset immediately before updating it. Preserve any
newer unrelated rules and save its prior JSON for recovery. Apply the reviewed
parameter change and empty bypass list, then read back the full ruleset. Do not
send this parameter fragment as a whole-ruleset replacement.

Separately approve replacing the Amp project's saved custom Ship prompt with
the reviewed `.agents/ship.md`. Editing the source file alone does not update
Amp settings. Do not activate the old direct-main Ship prompt as a workaround.
Legacy commands that combine direct main publication with activation, such as
`hey agents-rollout`, are not this route. Prepare their source changes locally
and submit the resulting dotfiles candidate instead.

## Authorized rollout and recovery

After explicit publication and settings approval:

1. Submit this implementation as a candidate. GitHub uses the candidate's
   version of `ci.yml` for its push trigger, so candidate checks can run before
   the implementation is on main. Subscribe, then inspect the actual run,
   selected base and required contexts. Do not claim hosted proof from local
   simulated GitHub responses.
2. Apply and verify the reviewed ruleset changes before landing. If GitHub
   rejects the exact green candidate, inspect the required-context provider and
   commit identities. Do not turn bypass back on or create a PR merely to mask
   a configuration error.
3. Land the exact green SHA, verify remote main, then activate the approved
   custom Ship prompt. No deployment follows unless separately authorized.
4. Verify server-side rejection of an unvalidated main update only in an
   explicitly approved disposable test repository with equivalent rules. Do
   not probe production main with an unchecked commit: a misconfiguration
   could actually land it.

For code rollback, submit a revert through the same candidate path. A
settings rollback requires administrator approval and the saved prior JSON;
restoring bypass would explicitly weaken admission protection. Do not reset
or force main backward. If access is blocked, an administrator should repair
the narrow ruleset error rather than grant the agent new privileges.
