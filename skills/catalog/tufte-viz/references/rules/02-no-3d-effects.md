# Rule 2: No 3D effects

## Intent

Represent quantitative information in flat 2D unless there is a truly necessary spatial reason not to.

## Pass signals

- Flat bars, points, lines, and areas
- No simulated depth
- No perspective view

## Fail signals

- 3D bars, pies, or perspective plots
- Drop shadows used to simulate depth
- Tilted axes or faux perspective
- Bevels or extrusion effects

## Reviewer guidance

Treat decorative depth as a straightforward fail. The fix is usually simple: remove the 3D treatment and keep the same chart in 2D.
