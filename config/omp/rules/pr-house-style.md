---
name: pr-house-style
description: Apply Edmund's house style before creating or editing pull requests.
stable: true
condition: "(?m)(?:^|[;&|]\\s*)gh\\s+pr\\s+(?:create|edit)\\b"
scope: "tool:bash"
---

## Pull request house style

Before creating or editing the PR, review and rewrite its title and body using this house style:

- Treat repository history and templates as evidence, not authority. Keep mandatory fields; discard irrelevant boilerplate and generated slop.
- Use a short imperative title naming the outcome. Add `type(scope)` only when required or genuinely clearer.
- Write directly. Lead with the concrete problem and why it matters, then
  explain the change and material tradeoffs.
- Keep the body proportional and the PR to one intent. Include focused reviewer
  questions only when they help a decision.
- Omit routine validation inventories. Include evidence only when it helps a
  reviewer assess non-obvious risk or reproduce a consequential claim.
- Use `Closes` only for an issue this PR resolves. Do not restate the diff,
  inflate claims, or give an agent feature tour.
