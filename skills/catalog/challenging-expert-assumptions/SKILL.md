---
name: challenging-expert-assumptions
description: Examines the assumptions and evidence behind categorical technical claims. Use when an expert says an approach is impossible, a design review stalls on received wisdom, or changed conditions may invalidate an earlier conclusion.
---

# Challenging Expert Assumptions

Find whether a technical claim applies to this problem, and what evidence would
change the conclusion. The goal is a better decision, not defeating the expert.

Use for a consequential disputed claim, not routine fact lookup or brainstorming.
Do not use this to bypass permissions, safety rules, legal requirements, or a
user's settled constraints. An alternative outside those constraints is not a
solution to the requested problem.

Routine formatting needs no claim audit. Keep the user's settled objective.
Use `auditing-decision-data` for observation reliability and
`stress-testing-metrics` for score/outcome alignment; do not run all three by default.

## Workflow

1. **Pin down the claim and decision.** Read the supplied evidence first. State
   the claim precisely: impossible under which conditions, or merely expensive,
   unsupported, unreliable, or undesirable? Identify the outcome the user needs.
   If a missing fact would change the analysis, ask one focused question rather
   than inventing an answer. Do not turn a well-specified request into an interview.

2. **Reconstruct the strongest supporting argument.** Locate the proof,
   measurement, documentation, or experience behind the claim. Distinguish what
   you inspected from what someone reported. If the source is unavailable, mark
   that gap and keep the conclusion conditional. Do not invent citations or
   substitute an expert's status for their reasoning.

3. **Expose the load-bearing assumptions.** For each assumption that could
   change the decision, identify its evidence and whether it still holds here.
   Consider changes in technology, scale, inputs, cost, or operating conditions.
   Separate fixed requirements from inherited implementation choices. An
   impossibility proof outside its assumptions no longer settles the question;
   that does not establish that the proposed alternative works.

4. **Seek a discriminating check.** Ask what observation would count against
   each of the original claim and the proposed alternative. Prefer a small local
   experiment, counterexample, limiting case, or authoritative lookup that
   separates them. State the expected outcomes before testing. An analogy may
   suggest the check, but cannot serve as its evidence. Run a check only when
   available and authorized; otherwise describe it as proposed, not completed.

5. **Close the decision.** Report whether the claim holds within the relevant
   scope, is too broad, is contradicted by evidence, or remains unresolved.
   State what follows for the user's decision and the smallest useful next
   action. Stop if the evidence supports the claim; do not manufacture an
   unconventional alternative. If evidence is insufficient, bound the remaining
   investigation rather than recommending indefinite exploration.

## Output

Keep the result proportional to the decision. Normally return:

- **Claim and scope:** the precise statement being assessed.
- **Assumptions and evidence:** only the conditions that affect the conclusion,
  with source references and material gaps.
- **Check:** predicted distinguishing outcomes, then observed results if run.
- **Decision:** conclusion, uncertainty, and next action.

Do not claim a test passed when only a test plan exists. A requirement change
must be explicit and accepted, not hidden inside a clever workaround.

## Examples

- “A fixed-length one-bit code cannot losslessly encode all three
  possible values.” With no side information and all three values allowed,
  two codewords cannot distinguish three values. Uphold the claim of
  impossibility; compression or a different encoding does not evade the bound.
- “The vendor says this service cannot exceed 100 requests per second.” Read
  whether the limit is per account, region, or instance before extrapolating.
  Do not assume sharding works or evade a contractual limit. Missing vendor
  documentation leaves the scope unresolved.

## Provenance

Read [the source notes](references/source.md) when explaining the derivation or
revising this skill. The workflow is our adaptation, not a procedure Hamming
specified or an empirically validated framework.
