---
name: via-negativa
description: Simplifies bloated products, offerings, documents, plans, and flows through purpose-locked subtraction. Use when asked to cut scope, remove bloat, create a kill list, decide what to keep or remove, or improve something by subtraction. Do not use for code-only refactors, optimizing individual flow steps, release prioritization, or evaluating one proposed addition.
---

# Via Negativa

Remove what does not serve one explicit purpose. Make the result simpler without weakening required outcomes or constraints.

## Workflow

1. **Lock one purpose.** Write one sentence:

   > This exists to help [specific beneficiary] achieve [single outcome].

   Infer it from supplied context when confidence is high and label the inference. Otherwise ask one focused question. If the sentence contains independent jobs, select one scope or split the artifact before continuing.

2. **Separate constraints.** List non-negotiable safety, legal, accessibility, reliability, contractual, and compatibility obligations. Constraints are not extra purposes.

3. **Inventory the whole thing.** Enumerate every feature, section, field, step, claim, option, dependency, or commitment in scope. Inspect the actual artifact when available; do not judge from a summary if the source can be read.

4. **Classify every element.**
   - **KEEP:** directly enables the purpose or satisfies a constraint.
   - **CUT:** does neither. “Nice to have,” sunk cost, ownership, and political attachment do not qualify an element to stay.
   - **RISKY CUT:** appears unnecessary, but removal has a credible failure mode. State that downside, then resolve it to **KEEP** or **CUT**. Never leave “maybe” as the decision.

5. **Execute the subtraction.** When the user requested edits, remove the decided cuts from the source artifact. Otherwise provide a concrete cut plan or stripped version. Keep uncertain execution reversible with a flag, staged rollout, archive, or rollback point; reversibility does not replace the keep-or-cut decision.

6. **Recheck the result.** Confirm the stripped artifact still achieves the purpose and honors every constraint. Only propose an addition if subtraction exposed a purpose-critical gap that cannot be closed by retaining or reshaping an existing element.

## Decision rules

- Judge contribution to the purpose, not effort already spent.
- Preserve evidence and provenance needed to trust the result.
- Do not equate fewer words, screens, or features with success; the purpose and constraints are the test.
- Do not invent user evidence, dependencies, or removal risk. Mark assumptions and evidence gaps.
- Prefer reshaping over adding when an existing element can do the job more simply.
- Route code-only cleanup to a code simplification workflow; route sequence-level friction, release ordering, or addition review to their task-specific workflows.

## Output

Return:

1. **Purpose:** the one-sentence purpose and constraints.
2. **Decision table:**

   | Element | Purpose/constraint contribution | Removal downside | Decision | Reason |
   | ------- | ------------------------------- | ---------------- | -------- | ------ |

3. **Cuts:** ordered by impact, with reversible execution where useful.
4. **Stripped result:** the edited artifact, concise rewrite, or exact target state.
5. **Verification:** evidence that the result still performs its one job and honors constraints.

## Example

For a PRD whose purpose is “help support leads find unassigned critical tickets before SLA breach”:

- Keep severity rules, ownership state, SLA timing, and alert acceptance criteria.
- Cut broad analytics, team biography, and unrelated dashboard customization.
- Treat per-channel alert settings as a risky cut: name the failure caused by one default channel, then choose keep or cut.
- Return the stripped PRD and verify every remaining requirement traces to the purpose or a constraint.

## Source

Distilled from George Nurijanian’s public description of [purpose-locked subtraction](https://x.com/nurijanian/status/2078456110944845969). This is an independent implementation; it does not reproduce the private PM OS skill.
