---
name: implementation-notes
description: Keep a running implementation-notes.html while implementing a spec. Use this whenever the user asks to implement a SPEC, PRD, design doc, issue, or feature and wants ongoing notes about design decisions, spec interpretations, deviations, tradeoffs, or open questions. Also trigger for prompts like “maintain implementation notes”, “document how this diverges from the spec”, or “capture anything I should know as you build”.
---

# Implementation Notes

When implementing from a spec, maintain a running `implementation-notes.html` file alongside the work. The notes are for the human reviewer: they should explain how the implementation interprets the spec, where it diverges, and what the reviewer may need to confirm.

## Core workflow

1. Locate and read the spec before changing code.
2. Create or update `implementation-notes.html` near the project root unless the user names a different location.
3. Keep the notes current as you work, not just at the end. Add entries whenever you make a meaningful interpretation, decision, or deviation.
4. Prefer concise, scannable notes over a long narrative. The file should help the user review the implementation quickly.
5. Before handing off, do a final pass over the notes and make sure they match the actual implementation.

## What to capture

Include these sections:

- **Design decisions**: choices made where the spec was ambiguous or underspecified.
- **Deviations from spec**: intentional departures from the spec, with the reason.
- **Tradeoffs considered**: alternatives considered and why the implemented approach won.
- **Open questions**: anything the user should confirm, revise, or decide later.

Only include items that matter. Do not fill sections with generic statements; use “None so far” when a section is empty.

## File format

Write a complete, readable HTML document. Keep it dependency-free: inline CSS is fine, but do not require external scripts, CDNs, or build steps.

Use this structure as a starting point:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Implementation Notes</title>
    <style>
      body {
        font-family: system-ui, sans-serif;
        line-height: 1.5;
        max-width: 900px;
        margin: 2rem auto;
        padding: 0 1rem;
      }
      h1,
      h2 {
        line-height: 1.2;
      }
      .meta {
        color: #555;
      }
      li {
        margin-block: 0.5rem;
      }
      code {
        background: #f4f4f4;
        padding: 0.1rem 0.25rem;
        border-radius: 0.25rem;
      }
    </style>
  </head>
  <body>
    <h1>Implementation Notes</h1>
    <p class="meta">Updated: YYYY-MM-DD HH:MM</p>

    <h2>Design decisions</h2>
    <ul>
      <li><strong>Decision:</strong> ... <br /><strong>Why:</strong> ...</li>
    </ul>

    <h2>Deviations from spec</h2>
    <ul>
      <li><strong>Deviation:</strong> ... <br /><strong>Why:</strong> ...</li>
    </ul>

    <h2>Tradeoffs considered</h2>
    <ul>
      <li>
        <strong>Options:</strong> ... <br /><strong>Chosen:</strong> ... <br /><strong
          >Reason:</strong
        >
        ...
      </li>
    </ul>

    <h2>Open questions</h2>
    <ul>
      <li>...</li>
    </ul>
  </body>
</html>
```

## Good notes

Good notes are specific and reviewable:

- “The spec says notifications should be sent after approval, but does not define retry behavior. I implemented three retries with exponential backoff to match the existing email worker.”
- “I did not implement bulk deletion because the spec mentions it only in the future-work section and there is no API contract yet.”
- “I chose server-side filtering over client-side filtering because the dataset can exceed 10k rows and the existing endpoint already supports indexed queries.”

Avoid vague notes like:

- “Made some UI decisions.”
- “Implemented differently for performance.”
- “Need to check stuff later.”

## Handoff

In the final response, mention the path to `implementation-notes.html` and summarize the most important open questions or deviations, if any. If there are no deviations or open questions, say so briefly.
