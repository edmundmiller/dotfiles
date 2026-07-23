---
purpose: Write AGENTS.md files that teach conventions, not list files.
rule_id: AGENT-14
enforced_by: prompt
severity: info
waiver_path: .agents/waivers/AGENT-14.md
---

# AGENTS.md Style

Treat `AGENTS.md` as a map, not the knowledge base. It should answer where a change belongs, who owns it, and how to verify it.

- Start repository work with `fd AGENTS.md` to find instruction boundaries; use focused `rg` patterns to find ownership, entrypoints, checks, and nearby examples.
- Notice navigation, ownership, and verification friction. If small, task-relevant guidance would prevent recurrence, improve the nearest `AGENTS.md` in the same change; otherwise report the opportunity.
- Route details to the nearest authoritative skill, doc, tool, or source instead of duplicating them.
- Prefer reusable `fd` or `rg` discovery commands over static file lists and stale tables.
- Give every new or touched canonical doc a short YAML summary closed by line 7: `purpose`, `applies_to`, `entrypoint`, `verification`, and `update_when`. Mechanize repeated drift with the smallest existing enforcement.
