# Rule 1: Data-ink ratio

## Intent

Maximize the share of ink devoted to the data rather than decoration.

## Pass signals

- Plain background
- Minimal borders or spines
- No unnecessary gridlines, or only very light horizontal guides
- No decorative textures, gradients, or shadows
- No duplicate legend + direct label combination

## Fail signals

- Thick gridlines competing with the data
- Heavy chart borders or bounding boxes
- Decorative backgrounds or fills
- Large legend boxes that could be replaced by direct labels
- Extra visual chrome that does not encode information

## Reviewer guidance

Default to removing decoration before changing the chart type. If a chart can be improved simply by deleting non-data elements, recommend that first.
