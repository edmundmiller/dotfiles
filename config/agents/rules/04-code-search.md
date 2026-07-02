---
purpose: Prefer structural search over plain text search for code relationships.
rule_id: AGENT-04
enforced_by: prompt
severity: warn
waiver_path: .agents/waivers/AGENT-04.md
---

# Code Search

For structural code questions, prefer indexes over text search:

- Use `ast-grep --lang <lang> -p '<pattern>'` for syntax-aware search.
- Use text search (`rg`, `grep`) for literal strings, comments, log messages, or after you already know the specific file/path.
