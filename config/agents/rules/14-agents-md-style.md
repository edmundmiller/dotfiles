---
purpose: Write AGENTS.md files that teach conventions, not list files.
---

# AGENTS.md Style

When writing AGENTS.md files, document **conventions, patterns, and gotchas** — not file inventories.

- Don't list files the agent can discover by listing the directory
- Don't maintain tables that go stale — provide a command to query live state instead
- Prefer "teach to fish": `nix flake metadata foo/ --json | jg '...'` over a static table of inputs
- Put metadata in the files themselves (e.g. YAML frontmatter `purpose:`) then query: `head -5 *.md | grep 'purpose:'`
