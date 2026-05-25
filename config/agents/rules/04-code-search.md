---
purpose: Prefer structural indexes (CodeGraph MCP, ast-grep) over text search for code relationships.
rule_id: AGENT-04
enforced_by: prompt
severity: warn
waiver_path: .agents/waivers/AGENT-04.md
---

# Code Search

For structural code questions, prefer indexes over text search:

- If `codegraph_*` MCP tools are available, use CodeGraph first for symbol lookup, callers/callees, impact, source snippets, and architecture/context questions. Start broad tasks with `codegraph_context`; use `codegraph_explore` for the surfaced symbols. Do not re-verify CodeGraph results with grep unless you need literal text.
- If CodeGraph is unavailable, use `ast-grep --lang <lang> -p '<pattern>'` for syntax-aware search.
- Use text search (`rg`, `grep`) for literal strings, comments, log messages, or after you already know the specific file/path.
- If CodeGraph reports the project is not initialized, ask whether to run `codegraph init -i`.
