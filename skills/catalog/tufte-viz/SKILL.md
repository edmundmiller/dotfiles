---
name: tufte-viz
description: |
  Ideate and critique data visualizations using Edward Tufte's principles from "The Visual Display of Quantitative Information." Use this skill when:
  (1) Designing new data visualizations or charts
  (2) Critiquing or improving existing visualizations
  (3) Reviewing dashboards or reports for graphical integrity
  (4) Deciding between visualization approaches
  (5) Reducing chartjunk or improving data-ink ratio
  (6) Planning small multiples or high-density displays
  Applies principles: data-ink ratio, chartjunk elimination, graphical integrity, lie factor, small multiples, and data density.
---

# Tufte Visualization Ideation

Apply Edward Tufte's principles to design clear, honest, high-density data visualizations.

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

4. **Apply the Tufte test** (see references/tufte-principles.md)

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
