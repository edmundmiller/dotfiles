---
purpose: Write AGENTS.md files that teach conventions, not list files.
rule_id: AGENT-14
enforced_by: prompt
severity: info
waiver_path: .agents/waivers/AGENT-14.md
---

# AGENTS.md Style

When writing AGENTS.md files, document **conventions, patterns, and gotchas** — not file inventories.

- Don't list files the agent can discover by listing the directory
- Don't maintain tables that go stale — provide a command to query live state instead
- Prefer "teach to fish": `nix flake metadata foo/ --json | jg '...'` over a static table of inputs
- Put metadata in the files themselves (e.g. YAML frontmatter `purpose:`) then query: `head -5 *.md | grep 'purpose:'`
