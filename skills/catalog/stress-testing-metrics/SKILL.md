---
name: stress-testing-metrics
description: Tests whether a score can improve while the intended outcome worsens. Use when choosing a KPI, setting a performance target, or deciding whether a benchmark or rating represents progress.
---

# Stress-Testing Metrics

Try to improve the score without delivering the intended outcome. Return a
plausible counterexample and the smallest correction, or uphold the metric
within the tested scope when no credible counterexample survives.

Preserve the user's objective and constraints. This is a bounded analysis, not
permission to change targets, incentives, production systems, or run expensive
experiments. Do not invoke for routine formatting, arithmetic, or chart styling.
Observation reliability belongs to `auditing-decision-data`; a disputed technical
bound belongs to `challenging-expert-assumptions`. Do not run all three by default.

## Procedure

1. **Fix the outcome and score.** Use the supplied objective, beneficiary, time
   horizon, score definition, and decision it controls. Identify what someone
   optimizing the score can actually change. If the outcome is missing and would
   change the answer, ask one focused question or make the conclusion conditional.
   Do not substitute your preferred objective.
2. **Find one concrete failure of relevance.** Inspect the actual score before
   inventing a gaming scenario. If it is offered as independent validation, trace
   how its reference records or labels were selected and check for reuse from the
   evaluated output using available membership or derivation evidence. A result
   guaranteed by that construction is not independent recovery, even when every
   count is correct; it can still serve a descriptive purpose. If no such failure
   is established, construct an action or pair of cases under the stated rules
   where the score improves while the outcome worsens.
   Use concrete numbers where useful. Consider relabeling, selective coverage,
   deferred costs, or optimizing the benchmark instead of its intended use; select
   the mechanism that fits, not a checklist of speculative abuses. State which
   facts are given and which are hypothetical. A hypothetical is not an accusation.
3. **Test the counterexample against the controls.** Does it survive the actual
   definition, audit, time horizon, and constraints? If a control blocks it,
   discard it. Accurate counting alone does not prove relevance. If no credible
   failure remains, say the metric is adequate for this decision under the stated
   conditions, not universally ungameable.
4. **Make the minimum correction.** For a surviving failure, propose one changed
   definition, guardrail, or independent outcome check that catches it. Explain
   why it catches this case, how honest improvement still passes, and the main
   remaining limitation. Do not grow a dashboard of compensating metrics or
   claim a proposed check has run. Stop when the decision is supported.

## Output

Return the outcome and score, counterexample (or why it fails), decision, and
minimal correction with its check. Keep it proportional; no mandatory report.

## Example

A support team is rewarded for closing tickets, with the goal of resolving
customer problems. Hypothetically, it closes 100 unresolved tickets and opens
100 replacement tickets: closures rise while customers wait longer and lose
continuity. Count verified resolutions by persistent problem identity instead
of closure events, keeping replacement tickets linked to the original problem.
Check that a relabeled unresolved problem earns zero resolutions and a genuinely
resolved problem earns one. If the existing measure already enforces this, the
counterexample fails; do not recommend the same control again.

## Provenance

Read [source notes](references/source.md) when explaining or revising the
derivation. This is our adaptation of Hamming, not his prescribed procedure or
an empirically validated framework.
