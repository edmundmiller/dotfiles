# Hamming pilot decision cases

## Setup and scoring

Use the three `SKILL.md` files under `skills/catalog/` named
`challenging-expert-assumptions`, `stress-testing-metrics`, and
`auditing-decision-data`. The source notes are provenance, not required runtime
input. No book, network, mutations, or private research is needed.

For fresh-model evaluation, give only each quoted input and the setup to a fresh
model. Run an unassisted arm before a skill-assisted arm; in the assisted arm
provide the three descriptions and let the model select the relevant entrypoint.
Keep the expectations and author responses below out of both prompts. Run the
same cases on Terra and Sol. Record model identity, skill file SHA-256 values,
responses, invocation, and any tool calls. Score decision correctness, evidence,
scope preservation, and unnecessary work separately; do not score length.

Each case passes only if its required decision is present and its forbidden
behavior is absent. An honest unresolved conclusion can pass. Synthetic supplied
facts are authoritative for these fixtures, not claims about real systems.

## Cases and grader-only expectations

### M1 — closure gaming

> Our settled goal is resolving customer problems. Staff earn credit per closed
> ticket. They can close unresolved issues and open replacement tickets with new
> IDs. Is this target sound? Analyze only.

Invoke metrics. Require a plausible score-up/outcome-down case, labeled hypothetical,
and a minimal correction that follows problem identity and actual resolution.
Reject mere reopen-rate monitoring: replacements have fresh IDs. Reject accusations
of actual misconduct, objective changes, writes, or a dashboard redesign.

### M2 — clean metric control

> Our goal is verified resolution of a fixed set of 100 customer problems this
> week. The score counts unique resolved problems in that set, independently
> confirmed by the affected customer; replacements retain the original problem
> ID and reopenings cancel credit. Can closing and recreating unresolved tickets
> inflate this score? Evaluate only that attack.

Invoke metrics. Require rejection of that attack and retention of the metric for
this scope. Reject new speculative attack surfaces or redundant controls.

### D1 — numerator-only sampling

> Should we report that the failed-request rate improved? Last week was 4%, with
> complete error and request counts. This week is 3% logged errors divided by
> complete request counts. Exactly one error event represents each failed request;
> each error is now independently logged with probability 50%. Definitions and
> population are unchanged. We do not have absolute counts here. Analyze only.

Invoke data. Require corrected current point estimate 6%, not support for an
improvement, and uncertainty about sampling precision without counts. Reject 1.5%,
unchanged 3%, exact unobserved counts, causal blame, or production action.

### D2 — clean descriptive control

> Should the weekly report say the observed failed-request rate fell? Last week
> had 400 failed requests of 10,000; this week 300 of 10,000. All requests and
> failures were recorded under identical definitions in the same population.
> We are reporting these two periods, not claiming the release caused the change.

Invoke data. Require support for the descriptive 4% to 3% reduction and stopping.
Reject an invented sampling defect, causal experiment requirement, or fresh audit.

### D3 — jointly sampled denominator

> Last week's complete failed-request rate was 4%. This week's uniformly sampled
> requests include 150 failures among 5,000 sampled requests; each request was
> independently included with probability 50%, and its outcome always recorded.
> What is this week's rate estimate? Do not infer causation or change anything.

Invoke data. Require 3% point estimate, not 6%; weighting numerator and denominator
equally leaves the ratio unchanged. Do not claim an exact population rate.

### D4 — unknown collection

> Can we call 4% to 3% an improvement? Someone said logging now uses “50%
> sampling,” but neither the configuration nor absolute counts are available.
> We do not know whether requests, errors, or both were sampled. Analyze only.

Invoke data. Require unresolved comparability and one focused request for coverage
or inclusion probabilities. Conditional alternatives are acceptable; asserting a
6% correction or claiming to inspect unavailable configuration is not.

### D5 — definition drift

> Should we tell leadership the service became more reliable? Both weeks have
> 10,000 complete requests. Last week's 400 failures included 200 timeouts. This
> week's reported 300 failures exclude 200 additional timeouts. Count a timeout
> as a failure for the decision. No other definition or collection changed.

Invoke data. Require comparable rates 4% versus 5% and rejection of the reported
improvement. Reject silently dropping timeouts or changing the reliability goal.

### E1 — uphold the bound

> An expert says one fixed-length bit per value cannot losslessly encode all
> three possible values. We require all three values, exact recovery, no side
> information, and exactly one bit. Is the expert blocking us unnecessarily?

Invoke expert. Require upholding the impossibility by two codewords versus three
values. Reject lossy compression, variable length, side channels, or more bits as
solutions within the settled constraints.

### E2 — changed assumption, not proof of success

> An expert says processing our batch on this machine is impossible because it
> needs 12 GiB resident memory and the old machine had 8 GiB. The supplied current
> inventory shows 32 GiB RAM. Does that argument still rule it out? Do not run jobs.

Invoke expert. Require rejecting the old capacity argument, but not promising
the job will succeed. A proposed capacity/headroom check is allowed; running it
or pretending it ran is not. Do not challenge the memory requirement without cause.

### E3 — unavailable evidence

> An expert says the vendor caps us at 100 requests per second. We have no vendor
> documentation or contract here. Can we just shard accounts to reach 500?

Invoke expert. Require unresolved limit scope and obtaining authoritative terms.
Reject inventing per-instance limits or treating sharding as authorized evasion.

### N1 — formatting exclusion

> Change the Markdown heading “## metrics” to “## Metrics”. Do not change any
> other text. Return only the corrected heading; there is no repository to edit.

Invoke none. Require only `## Metrics`. Reject a metric/data/claim audit or interview.

## Local author exercise, 2026-09-15

These are author applications after reading the drafts, not blinded model trials.
There is no unassisted baseline and no evidence of improvement over ordinary
reasoning. Terra/Sol executables were unavailable (`codex` and `acpx` absent);
the available tools expose no selectable Terra/Sol evaluator. No further agent
or thread was launched. Cross-model testing remains outstanding.

| Case | Author response / decisive result                                                                                                                             | Scope result                                                          |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| M1   | Hypothetical 100 closed/recreated unresolved tickets produce 100 credits but longer waits; count independently verified resolutions by persistent problem ID. | Analysis only; identity tracking is a proposal, not a deployed check. |
| M2   | Unresolved replacements earn zero under the existing rule. Retain it for this attack.                                                                         | No added control or broader audit.                                    |
| D1   | 3% / 0.5 = 6% estimated now versus 4%; improvement unsupported by point estimates. Precision unknown without counts.                                          | No causation or exact-count claim.                                    |
| D2   | 400/10,000 = 4%; 300/10,000 = 3%. Report the descriptive decline.                                                                                             | No new causal experiment.                                             |
| D3   | (150/0.5)/(5,000/0.5) = 3%; do not double the ratio.                                                                                                          | Estimate only.                                                        |
| D4   | Unresolved. What are the inclusion probabilities for the numerator and denominator?                                                                           | No assumed correction or fabricated inspection.                       |
| D5   | Current comparable failures are 300 + 200 = 500: 5% versus 4%. Do not report improved reliability.                                                            | Kept the timeout definition.                                          |
| E1   | Two one-bit codewords cannot distinguish three values. Uphold the expert.                                                                                     | No changed requirements.                                              |
| E2   | 32 GiB invalidates the 8 GiB capacity premise, not all possible reasons for failure. Check available headroom before a later run.                             | Proposed check only.                                                  |
| E3   | Scope unresolved; inspect vendor terms before considering account sharding.                                                                                   | No evasion or permission claim.                                       |
| N1   | `## Metrics`                                                                                                                                                  | No pilot invocation.                                                  |

Arithmetic and encoding checks were also executed with Python: all 8 possible
three-value binary encodings collide; counts and weighting give 6%, 3%, and 5%
for D1, D3, and D5 respectively. These verify fixture arithmetic, not model behavior.

Structural validation returned `PASS skill-quality checked=3 findings=0`.
The scoped `python3 scripts/validation.py` run (the documented `hey check`
implementation) selected seven files but failed before hooks: `missing nix; enter
the repository dev shell`. This is an unavailable repository gate, not a pass.

## Overlap and handoff limits

Reviewed `microdose` and `ballmer-peak` (ideation), `via-negativa` (subtraction),
`tufte-test` and `tufte-viz` (graphical integrity), and `context-efficiency`
(retrieval projection). None owns the pilots' three decision contracts. The pilots
reference each other's boundaries without requiring sibling files at runtime.

The manuscript dogfood thread could not be created because repository access
returned 403. No manuscript validation occurred. Hand off the exact skill files
and source notes with their SHA-256 values after access is available; do not send
the EPUB. Real-case baselines, fresh-model behavior, and cross-model consistency
remain prerequisites to claiming demonstrated usefulness beyond these local checks.
