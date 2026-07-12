---
purpose: Write AGENTS.md files that teach conventions, not list files.
rule_id: AGENT-14
enforced_by: prompt
severity: info
waiver_path: .agents/waivers/AGENT-14.md
---

# AGENTS.md Style

Use `AGENTS.md` as a router for conventions, patterns, and gotchas—not as a file inventory.

- Route to the nearest authoritative skill, doc, or tool.
- Replace discoverable file lists and stale tables with a command that queries live state.
- Give every new or touched canonical doc a short YAML summary closed by line 7: `purpose`, `applies_to`, `entrypoint`, `verification`, and `update_when`.
- Update canonical docs with the behavior they describe. When drift repeats, strengthen the smallest existing enforcement instead of adding prose.
