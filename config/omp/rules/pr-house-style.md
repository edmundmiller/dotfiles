---
name: pr-house-style
description: Apply Edmund's house style before creating or editing pull requests.
stable: true
condition: "(?m)(?:^|[;&|]\\s*)gh\\s+pr\\s+(?:create|edit)\\b"
scope: "tool:bash"
---

## Pull request house style

Before creating or editing the PR, review and rewrite its title and body using this house style. The body shape follows Simon Willison's details-summary pattern: https://simonwillison.net/2026/Nov/9/details-summary/

- Treat repository history and templates as evidence, not authority. Keep mandatory fields. Discard irrelevant boilerplate and generated slop.
- Use a short imperative title naming the outcome. Add `type(scope)` only when required or genuinely clearer.
- Keep the PR to one intent.

Start the body with a short opener. Say what changed and why it matters to a reviewer. The opener is what is definitely worth the reviewer's time. Do not inflate it. Add one screenshot, CLI excerpt, or diagram only when it shows the change faster than another sentence. For a diagram, use `show-me` and pick the smallest call-tree, component, file-layout, or Mermaid view. That view replaces prose that restates the diff.

Put a `Closes` line in the opener only for an issue this PR resolves. Put a reviewer question in the opener only when the reviewer must answer it.

Put the full agent-written details in one collapsed block. Include the problem, implementation, decisions, tradeoffs, verification, longer questions, and linked-issue context. Keep evidence that lets a reviewer judge non-obvious risk or reproduce a consequential claim. Omit a routine validation inventory. Keep a template's required fields. Move long agent-written field text into the collapsed block.

Name the model in `<summary>`, and the effort level when that is known, for example `<summary>Claude Opus 5.5 Medium</summary>`. When the model is unknown, use `<summary>Agent details</summary>`. Do not invent a model or an effort level.

Write `<details>` and then `<summary>`. Leave a blank line after `</summary>` and before `</details>` so GitHub renders Markdown inside the block. The example is a shape. Replace its facts with this PR's facts.

```markdown
The row page now lists one field per row, so a wide table stays on the page.

Closes #3052

<details>
<summary>Claude Opus 5.5 Medium</summary>

The row page showed its single row as a table. A 46-column table scrolled off the side and left most of the page blank.

The row template now renders each column as a field row. The change is limited to the row page.

`pkg-check datasette` passed. The row-page test covers a 46-column table.

</details>
```

Omit `Closes` and any image or CLI excerpt when they do not apply. Do not turn the collapsed block into a feature tour.
