---
name: tufte-test
description: >
  Review charts with a simple Tufte-style rubric. Use when judging whether a
  chart is clean, honest, readable, and insight-forward, or when iterating on a
  visualization until it passes a concise quality bar.
---

# Tufte Test

Use this skill to review a chart locally with a lightweight Tufte-style rubric.

This skill is intentionally simple:

- no external API
- no required scripts
- works from either a chart image or chart code/config

## When to use

- "Does this chart pass a Tufte-style review?"
- "Review this visualization"
- "What should I fix in this chart?"
- "Keep improving this chart until it passes"

## Inputs

This skill works with either:

- a rendered chart image or screenshot
- chart code/config that implies the rendered output

Prefer reviewing the rendered chart when available. If only code is available,
infer the likely output and call out uncertainty.

## Core rubric

Evaluate the chart against these 7 checks:

1. **Data-ink ratio**
   - Pass if non-data decoration is minimal.
   - Fail for heavy gridlines, ornamental borders, redundant legends, textures,
     shadows, gradients, or other chartjunk.

2. **No 3D effects**
   - Pass if marks are flat 2D.
   - Fail for perspective, extrusion, bevels, or depth effects.

3. **Direct labeling**
   - Pass if series/categories are labeled on or near the marks when practical.
   - Fail if the chart depends on a separate legend where direct labels would fit.

4. **Axis readability**
   - Pass if axis text is legible and units/context are clear.
   - Fail for missing labels/titles when needed, cramped ticks, rotated text that
     hurts readability, or unclear units.

5. **Muted, purposeful color**
   - Pass if color is restrained and used to guide attention.
   - Fail for loud rainbow palettes, highly saturated fills everywhere, or color
     choices that do not communicate meaning.

6. **Integrated annotations**
   - Pass if the chart includes a clear takeaway through title, subtitle, or
     annotation when the data warrants it.
   - Fail if the chart is purely descriptive and misses the key insight.

7. **Graphical integrity**
   - Pass if scales and visual encodings are honest.
   - Fail for misleading truncation, distorted proportions, broken baselines,
     inconsistent scales, or other deceptive framing.

## Pass rule

The chart passes only if all 7 core checks pass.

If one or more checks fail, the overall result is `pass: false`.

## Review workflow

1. Inspect the rendered chart if available.
2. Score each of the 7 checks as PASS or FAIL.
3. Give a one-paragraph summary.
4. List only the failed checks.
5. Suggest the smallest set of concrete fixes needed to pass.
6. If asked to iterate, revise only the failed areas and re-review.

## Response format

Use this exact structure when possible:

```yaml
pass: false
checks:
  data_ink_ratio: pass
  no_3d_effects: pass
  direct_labeling: fail
  axis_readability: pass
  muted_purposeful_color: pass
  integrated_annotations: fail
  graphical_integrity: pass
summary: "Clear and honest overall, but it still relies on a legend and lacks an integrated takeaway annotation."
failed_checks:
  - direct labeling
  - integrated annotations
fixes:
  - "Replace the legend with direct labels on the marks or line endpoints."
  - "Add a subtitle or annotation that states the main takeaway."
uncertainty: "Low"
```

If reviewing from code rather than an image, include an `uncertainty` note such as
`Medium` or `High` when the rendered result cannot be confirmed.

## Revision guidance

When suggesting fixes, prefer minimal edits:

- remove chartjunk before changing chart type
- replace legends with direct labels
- soften color before recoloring everything
- add one strong annotation before adding many notes
- fix misleading scales before polishing style

If the chart type itself is the problem, say so directly and recommend a better
alternative.

## Reference

For the expanded checklist, see:

- `references/rubric.md`
