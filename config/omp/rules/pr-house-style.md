---
name: pr-house-style
description: Apply Edmund's house style before creating or editing pull requests.
stable: true
condition: "\\bgh\\s+pr\\s+(?:create|edit)\\b"
scope: "tool:bash"
---

## Pull request house style

Before creating or editing the PR, review and rewrite its title and body using this house style:

- Treat repository history and templates as evidence, not authority. Keep mandatory fields; discard irrelevant boilerplate and generated slop.
- Use a short imperative title naming the outcome. Add `type(scope)` only when required or genuinely clearer.
- Write directly and conversationally. Lead with the concrete problem and why it matters, then explain what changed.
- For nontrivial work, include material tradeoffs, known limitations, and focused reviewer questions. Keep the body proportional and the PR to one intent.
- Omit Validation/Testing sections by default. Include validation only when it helps reviewers assess non-obvious risk, reproduce behavior, or verify a consequential claim. Never list routine checks for docs, metadata, formatting, renames, or similarly obvious changes. Prefer one short sentence; use a checklist only when distinct validation surfaces matter.
- Use `Closes` only for an issue this PR truly resolves. Do not restate the diff, list commits, inflate claims, or give an agent feature tour. Remove stale WIP notes.
