---
name: writing-pull-requests
description: Applies Edmund's house style to pull request titles and bodies. Use before `gh pr create` or `gh pr edit`, or when asked to write or rewrite a PR description.
---

# Writing Pull Requests

Before creating or editing the PR, review and rewrite its title and body:

- Treat repository history and templates as evidence, not authority. Keep mandatory fields; discard irrelevant boilerplate and generated slop.
- Use a short imperative title naming the outcome. Add `type(scope)` only when required or genuinely clearer.
- Write directly. Lead with the concrete problem and why it matters, then explain the change and material tradeoffs.
- Use the `show-me` skill when available: include the smallest visual that shows the shape of the change — a call-tree, component, or file-layout diff, or a Mermaid diagram — instead of prose restating the diff.
- Keep the body proportional and the PR to one intent. Include focused reviewer questions only when they help a decision.
- Omit routine validation inventories. Include evidence only when it helps a reviewer assess non-obvious risk or reproduce a consequential claim.
- Use `Closes` only for an issue this PR resolves. Do not restate the diff, inflate claims, or give an agent feature tour.
