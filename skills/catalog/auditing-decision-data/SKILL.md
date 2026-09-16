---
name: auditing-decision-data
description: Checks whether observations support a consequential decision. Use when a reported trend, experiment, survey, or operational rate may be distorted by collection, sampling, denominators, or changing definitions.
---

# Auditing Decision Data

Find whether the observations support this decision, and whether a plausible
data defect would change it. Reliable enough is decision-specific, not perfection.

Preserve the user's settled objective. Do not audit routine formatting, simple
arithmetic, or every dataset encountered. This skill authorizes bounded analysis,
not production writes, new data collection, expensive experiments, or an extra
approval gate. Score/outcome alignment belongs to `stress-testing-metrics`;
disputed technical bounds belong to `challenging-expert-assumptions`. Do not run
all three by default.

## Procedure

1. **Name the decision and comparison.** State what action depends on the data,
   the population and period, and any supplied decision threshold. Separate the
   observed comparison from causal claims. Do not invent a threshold or require
   causal proof when a descriptive decision does not need it.
2. **Trace the relevant observations.** Read available definitions and collection
   evidence, not only a displayed aggregate. For the parts that could change the
   decision, inspect who or what was recorded, inclusion and missingness, sampling
   probabilities, numerator and denominator coverage, units, and definition or
   instrumentation changes across periods. Check plausible consistency errors
   or outliers without silently deleting them. Do not expand into an exhaustive
   audit when the supplied evidence resolves these questions.
3. **Try to overturn the inference.** Pick the most consequential plausible
   defect and calculate its effect or bound it. Correct sampling only when the
   inclusion probabilities and coverage justify it; do not automatically double
   a rate because someone mentions 50% sampling. Separate measurement bias,
   sampling uncertainty, and model assumptions. A large sample does not remove
   bias; uncertain inputs do not become precise by being combined with precise
   ones. Report an estimate as an estimate, not the exact unobserved count.
4. **Close the decision.** Say supported, contradicted, or unresolved, within
   the inspected scope. If the decision survives the relevant uncertainty, retain
   it and stop. If not, state the corrected implication or the smallest missing
   fact/check that could settle it. Distinguish supplied facts, inspected evidence,
   assumptions, and proposed checks. Ask one focused question only when needed;
   do not demand perfect data or redesign the user's objective.

## Output

Return the decision, decisive data lineage/defect, correction or sensitivity,
and conclusion with remaining uncertainty. Include sources for inspected facts
and label unavailable evidence. No mandatory long report or confidence interval
without the information needed to compute it.

## Example

Reported errors fall from 4% to 3%. Previously all error events were logged;
now each error is independently logged with probability 50%. Request counts
remain complete, one error event means one failed request, and definitions are
unchanged. The corrected current estimate is 3% / 0.5 = 6%, versus 4% before:
the point estimates do not support an improvement. Counts are needed to quantify
sampling uncertainty; this does not prove that a release caused the change.
If requests and errors were both sampled together at 50%, the same correction
would be wrong. If coverage and definitions were unchanged and complete, the
4% to 3% descriptive reduction would stand.

## Provenance

Read [source notes](references/source.md) when explaining or revising the
derivation. This is our adaptation of Hamming, not his prescribed procedure or
an empirically validated framework.
