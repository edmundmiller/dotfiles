---
name: calibrating-instructions
description: Compares reusable prompt or skill changes against observed agent behavior. Use when empirically tuning instructions, not for ordinary prose edits.
license: MIT
metadata:
  source: https://github.com/IgorWarzocha/howaboua-pi-stuff/blob/c4f48525475f278d41dc311f2707926216bfa35b/packages/pi-skill-harness-and-agent-engineering/skills/instruction-calibration/SKILL.md
  pin: c4f48525475f278d41dc311f2707926216bfa35b
---

# Calibrating instructions

Start with a real request and the consequential choice the agent got wrong. State what must change and what must remain unchanged before editing the instructions.

## Define the comparison

- Use the natural request, its closest ambiguous decision boundary, and an unrelated request where the instruction should not apply. Do not put the desired solution into the test request.
- Compare fresh sessions with the same model, reasoning level, tools, working directory, task, and available files. Change only the candidate instruction.
- Inspect the instructions and files each session actually reads. Discovery flags do not prevent an agent from reading instruction files. Exclude contaminated baselines or restrict access equally.
- Give the working baseline its normal documentation and source access. A closed-book knowledge probe is not evidence of normal task performance.
- Judge the first response before coaching. Follow-ups and reloads are exploratory evidence, not clean comparisons of the original instruction.

## Run and judge

Propose the model, cases, run count, and expected cost before starting model-backed evaluations. Run them only with approval. Keep interactive comparisons visible when the user wants to inspect them; otherwise complete an authorized evaluation without pausing between probes.

Judge consequential choices, actions, omissions, and executable results rather than polish or matching wording. Verify generated work against the active API and run its relevant checks. Plausible output is not correctness.

One unusually good or bad run is weak evidence. Repeat when the decision depends on stability. Repair underspecified requests rather than enlarging reusable instructions to compensate.

## Keep the smallest effective change

- Separate instruction effects from missing context, model defaults, tool contracts, and local policy.
- Change one coherent condition and action. For each retained instruction, identify the failure its removal would restore.
- Rerun the same cases after shortening the candidate, especially the closest ambiguous case. Reject eager skill selection, added ceremony, and regressions on unrelated requests.
- Finish in the normal worker environment to check skill selection and conflicting instruction layers. Report this as integration evidence, not an isolated comparison.

Report the baseline, observed behavior change, active API checks, instruction-token change, and unresolved variance. Cost comparisons include the whole task, retries, and workers when available. A shorter prompt alone does not prove lower task cost. Do not turn model-compliance probes into permanent programmatic tests.
