# Tufte Test Rubric

Use this reference when you need slightly more detail than the main skill file.

## 1. Data-ink ratio

### Pass signals

- Plain background
- Minimal borders/spines
- No unnecessary gridlines, or very light horizontal-only guides
- No decorative textures, gradients, or shadows
- No duplicate legend + direct label combination

### Fail signals

- Thick gridlines competing with the data
- Heavy bounding boxes around the chart
- Decorative backgrounds or fills
- Large legend boxes that could be replaced by direct labels
- Extra visual chrome that does not encode information

## 2. No 3D effects

### Pass signals

- Flat bars, points, lines, and areas
- No simulated depth

### Fail signals

- 3D bars, pies, or perspective views
- Drop shadows used to simulate depth
- Tilted axes or faux perspective

## 3. Direct labeling

### Pass signals

- Line endpoints labeled directly
- Values or category names placed on or beside bars when practical
- Small number of series/categories labeled without requiring lookup

### Fail signals

- User must bounce between chart and legend to decode colors
- Legend used for only a few obvious series that could be labeled in-place
- Labels too far from the marks they describe

## 4. Axis readability

### Pass signals

- Tick labels are legible
- Units are clear
- Axis titles exist when needed for interpretation
- Label density is appropriate for the space available

### Fail signals

- Tiny or overlapping tick labels
- Ambiguous units
- Missing axis titles where the measure is unclear
- Extreme text rotation used as a workaround for poor layout

## 5. Muted, purposeful color

### Pass signals

- Mostly neutral palette with selective emphasis
- Color draws attention to the most important series or point
- Accessible contrast

### Fail signals

- Saturated red/green/blue across all marks
- Rainbow palette without meaning
- Too many competing highlight colors
- Color is the only way to distinguish important categories when a label could help

## 6. Integrated annotations

### Pass signals

- Title states the finding, not just the variables
- Subtitle gives context
- One or two annotations point to the most important feature

### Fail signals

- Generic title only (for example, "Sales by Month") when the chart is meant to communicate a takeaway
- No annotation for the notable spike, dip, crossover, or outlier
- Overannotation that creates clutter can also fail by hurting clarity

## 7. Graphical integrity

### Pass signals

- Bars start at zero when bar length encodes magnitude
- Scales are consistent and honest
- Aspect ratio does not distort interpretation
- Encodings match the data faithfully

### Fail signals

- Truncated bar baselines that exaggerate differences
- Broken axes without clear disclosure
- Distorted area/volume encodings
- Inconsistent scales across panels that invite false comparison

## Suggested reviewer stance

Default to strict but practical:

- If direct labels clearly fit, require them.
- If a title can carry the takeaway, do not demand extra annotation noise.
- If the chart is exploratory rather than publication-ready, say that explicitly but still apply the rubric.

## Minimal pass/fail summary template

```yaml
pass: true
summary: "Clean, readable, and honest. The chart uses restrained color, direct labeling, and a clear takeaway."
```
