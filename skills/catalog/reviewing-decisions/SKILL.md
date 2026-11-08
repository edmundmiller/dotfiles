---
name: reviewing-decisions
description: Checks decision evidence when sampling or definitions may distort observations, a KPI or benchmark may reward the wrong outcome, or a disputed technical claim may depend on outdated assumptions. Use for consequential data, metric, or expert-claim reviews, not routine arithmetic, formatting, or chart styling.
---

# Reviewing decisions

Check the evidence for the user's decision without changing their objective.
This skill combines the former `auditing-decision-data`, `stress-testing-metrics`,
and `challenging-expert-assumptions` entrypoints; their guides remain distinct.

## Choose the relevant guide

Read the request and available evidence, then load the guide whose question
matches the decision. Choose by the uncertainty, not words such as "metric",
"expert", or "data" alone.

| Question to settle                                                                                                                                                        | Read                                                             |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| Can we trust these observations or compare these periods? Check collection, sampling, denominators, missingness, or definition changes.                                   | [Data reliability](references/auditing-decision-data.md)         |
| Even if counted correctly, does this score represent the intended outcome? Check KPI gaming, benchmark relevance, or supposedly independent reference labels.             | [Metric relevance](references/stress-testing-metrics.md)         |
| Does this disputed technical claim apply under the current assumptions? Check impossibility arguments, expert limits, changed conditions, or missing supporting evidence. | [Technical claims](references/challenging-expert-assumptions.md) |

Use one guide by default. If the request explicitly raises more than one of
these questions, load only those guides and keep their conclusions separate.
An expert reporting a sampled rate still calls for the data guide if sampling
is the disputed issue. A benchmark built from its own outputs calls for the
metrics guide even when every count is correct.

If evidence is missing within a route, follow that guide's uncertainty handling;
do not ask the user to choose a skill. Ask one focused question only when the
decision itself is unclear. Requests for ordinary arithmetic, formatting, or
chart styling need none of these guides. Measured code-performance investigations
belong to `auditing-performance`, not this decision review.

## Preserve scope and stop

The guides authorize bounded analysis, not production writes, deployments,
new data collection, or expensive experiments. A contrary idea does not permit
evading access controls, contracts, safety rules, or settled user requirements.
Use supplied facts as supplied; distinguish inspected evidence, assumptions,
proposed checks, and executed checks. Never invent observations or citations.

Return the decision, the decisive evidence or counterexample, and any remaining
uncertainty. Uphold sound observations, metrics, or technical limits and stop;
do not manufacture objections or run every guide as a checklist.

The guides adapt Hamming's ideas, not a proven decision framework. Source notes
are for provenance or revision, not prerequisites for ordinary use:
[data](references/auditing-decision-data-source.md),
[metrics](references/stress-testing-metrics-source.md), and
[claims](references/challenging-expert-assumptions-source.md).
