---
name: markdown-graphs
description: Design and implement text-forward technical diagrams embedded in MDX using semantic HTML, CSS grids, ASCII-inspired typography, and SVG paths or motion. Use for article diagrams, process loops, comparison tables, formula illustrations, or terminal-style explanatory graphics; not for ordinary data charts, Obsidian knowledge graphs, or Mermaid-first architecture documentation.
---

# Markdown Graphs

Treat “markdown graph” as shorthand for a custom visual component used inside
MDX. It is not a native Markdown graph format. Preserve the user's publishing
medium: when the target only accepts plain Markdown, produce a static SVG or
image, or use Mermaid when portability matters more than art direction.

## Design the Explanation

1. Reduce the visual to one claim, comparison, sequence, or relationship.
2. Choose the smallest topology that explains it: table, nested geometry,
   left-to-right transformation, or loop.
3. Write the labels and values before drawing connectors.
4. Lay out the content on a strict character-like or 8px grid.
5. Add decoration only when it clarifies grouping, direction, or state.

If the message needs a paragraph to explain the diagram, simplify the diagram
before adding more structure.

## Choose the Rendering Primitive

| Content                                       | Preferred primitive                    | Why                                             |
| --------------------------------------------- | -------------------------------------- | ----------------------------------------------- |
| Rows and columns                              | Semantic HTML `<table>`                | Keeps data accessible and responsive            |
| Text that should linearize exactly            | `<pre>` with styled spans              | Preserves a character-cell composition          |
| Labels, formulas, and simple comparisons      | CSS Grid                               | Keeps live text easy to align and wrap          |
| Connectors, nested geometry, or precise paths | Inline SVG                             | Gives exact, responsive geometry                |
| Moving tracers or chips                       | SVG path plus CSS or `<animateMotion>` | Reuses the explanatory path as the motion track |

Prefer live HTML text with an `aria-hidden` SVG connector layer when practical.
Do not reach for Mermaid by default: its auto-layout is useful for portable
architecture documentation, but it works against this deliberately composed
visual language.

## Apply the Visual Grammar

Use the project's existing typography and color tokens first. When the project
has no established system, these sampled values are a useful starting point,
not canonical values:

```css
--graph-bg: #11110f;
--graph-ink: #c9c5bb;
--graph-muted: #343632;
--graph-accent: #3296f9;
```

- Use one regular-weight monospace face. Commit Mono or a good `ui-monospace`
  stack fits the reference style.
- Keep four visual roles: background, readable ink, subdued structure, and one
  vibrant accent.
- Reserve the accent for the title, the active state, or the moving tracer. It
  should explain where to look.
- Use bracketed uppercase titles such as `[ THE PROMPT LOOP ]` with modest
  tracking.
- Construct frames from quiet dashed strokes, `+` corner marks, brackets, and
  arrow glyphs. Keep the frame visibly weaker than the content.
- Use generous negative space and a consistent outer inset. Do not fill every
  cell in the grid.
- Avoid gradients, glows, shadows, decorative filled cards, multiple accents,
  and unnecessary rounded containers.
- Use tabular numerals for aligned measurements and tables.

## Add Motion Only to Explain

Treat motion as optional. Add it only when the user requests it, the provided
reference includes it, or the deliverable is explicitly an explanatory
animation. When motion is in scope, animate sequence, direction, propagation,
or a state change. Keep the labels and base structure still.

For a moving wire highlight, draw the path twice: a complete muted base and a
short accent segment above it. Normalize the path with `pathLength="1"` and
animate `stroke-dashoffset`:

```css
.trace {
  stroke: var(--graph-accent);
  stroke-dasharray: 0.08 0.92;
  animation: graph-travel 4s linear infinite;
}

@keyframes graph-travel {
  to {
    stroke-dashoffset: -1;
  }
}
```

Use SVG `<animateMotion>` with `<mpath>` when a glyph or numbered chip must
follow an existing path. Use linear motion for constant traversal and a strong
ease-in-out curve for deliberate movement between states.

- Keep explanatory loops calm enough to follow, usually about 3–5 seconds.
- Pause looping motion while the component is off-screen. Include that behavior
  in the delivered component rather than leaving it as follow-up advice.
- Honor `prefers-reduced-motion`; retain a meaningful static highlighted state.
- Never make animation necessary to read the message.

## Implement for MDX

Keep the article invocation small and the component reusable at the frame and
token level. Do not force unrelated diagrams into one universal schema.

```mdx
import { PromptLoop } from "@/components/PromptLoop";

<PromptLoop />
```

- Use an SVG `viewBox` and `vector-effect="non-scaling-stroke"` for responsive,
  crisp lines.
- Use `paint-order: stroke` with the background color when a title needs to cut
  through the frame behind it.
- Keep meaningful labels as text, not outlined paths or baked pixels.
- Wrap the visual in `<figure>` and provide an accessible name or visible
  `<figcaption>` that states its takeaway.
- Let the source remain a live component. Export a high-resolution SVG, PNG, or
  video only for channels that require a static asset.

## Verify the Result

Before calling the diagram complete, confirm:

- The takeaway remains clear with animation disabled.
- The accent has one semantic job and the muted structure recedes.
- Labels align to a consistent grid and no connector crosses readable text.
- The component remains legible and unclipped at its smallest target width.
- Reduced-motion behavior preserves the explanation.
- A rendered screenshot matches the intended MDX surface, not just an isolated
  component preview.

## Primary References

- [Emil Kowalski's original examples](https://x.com/emilkowalski/status/2089372767934115883)
- [Clarification that these are custom MDX visuals](https://x.com/emilkowalski/status/2089628749998231720)
- [SVG `animateMotion` technique](https://x.com/emilkowalski/status/2090153827835982120)
- [MDX component model](https://mdxjs.com/)
- [MDN: SVG `<animateMotion>`](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/animateMotion)
