---
name: tufte-viz
description: Designs and reviews charts with Tufte principles. Use for visualization design, graphical integrity, chartjunk reduction, dense comparisons, or a pass/fail Tufte test. Not for auditing data collection or KPI relevance.
---

# Tufte Visualization Ideation

Apply Edward Tufte's principles to design clear, honest, high-density data visualizations.

For a chart review or the former `tufte-test` request, read the
[seven-check review workflow](references/tufte-test.md). Prefer a rendered chart;
label uncertainty when reviewing only code. All seven checks must pass. Fix only
failed areas when asked to iterate. Designing a chart uses the workflow below;
it does not require a separate review skill.

## Workflow

### For new visualizations:

1. **Clarify the data story**
   - What comparisons matter?
   - What's the key insight to communicate?
   - Who's the audience?

2. **Select approach** using Tufte principles:
   - High comparison need → Small multiples
   - Dense data → Consider data tables, sparklines
   - Time-series → Line charts with minimal grid
   - Part-to-whole → Avoid pie charts; prefer bar/table

3. **Design with data-ink in mind**
   - Start minimal, add only what's necessary
   - Every element must earn its ink
   - Default to grayscale; use color purposefully

4. **Apply the Tufte test** using the [review workflow](references/tufte-test.md).

### For critiquing visualizations:

1. **Check graphical integrity**
   - Calculate lie factor if proportions seem off
   - Verify baselines and scales
   - Look for 3D distortion

2. **Identify chartjunk**
   - Decorative elements
   - Heavy grids
   - Unnecessary 3D effects
   - Moiré patterns

3. **Evaluate data-ink ratio**
   - What can be erased?
   - What's redundant?

4. **Suggest improvements** with specific before/after recommendations

## Key Principles Reference

- `references/tufte-principles.md` — core principles from _Visual Display of Quantitative Information_: lie factor, data-ink, chartjunk, small multiples, integrity.
- `references/analytical-design.md` — extensions from _Envisioning Information_, _Visual Explanations_, and _Beautiful Evidence_: the 6 principles of analytical design, sparklines, layering & separation, micro/macro, range-frames, causality, confections. Load when designing dashboards, dense displays, sparklines, or explanatory graphics.

For a specific failed review check, read its detailed rule:
[data-ink](references/rules/01-data-ink-ratio.md),
[3D effects](references/rules/02-no-3d-effects.md),
[direct labeling](references/rules/03-direct-labeling.md),
[axes](references/rules/04-axis-readability.md),
[color](references/rules/05-muted-purposeful-color.md),
[annotations](references/rules/06-integrated-annotations.md), or
[integrity](references/rules/07-graphical-integrity.md).
The [rubric](references/rubric.md) summarizes the pass rule.

**Quick checklist:**

- [ ] Lie Factor ≈ 1.0 (no visual distortion)
- [ ] Maximum data-ink ratio
- [ ] Zero chartjunk
- [ ] Clear labeling
- [ ] Answers "compared to what?"
- [ ] Shows causality or mechanism where relevant
- [ ] Multivariate (not over-reduced)
- [ ] Words, numbers, images integrated — not segregated
- [ ] Reveals multiple levels of detail (micro + macro)
- [ ] Layering: primary data dominates, secondary recedes
- [ ] Appropriate data density
