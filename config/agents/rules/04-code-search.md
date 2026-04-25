---
purpose: Default to ast-grep for structural code search over text-based tools.
rule_id: AGENT-04
enforced_by: prompt
severity: warn
waiver_path: .agents/waivers/AGENT-04.md
---

# Code Search

`ast-grep` is installed. Default to `ast-grep --lang <lang> -p '<pattern>'` for structural/syntax-aware search. Use text search (`rg`, `grep`) only for plain-text queries.
