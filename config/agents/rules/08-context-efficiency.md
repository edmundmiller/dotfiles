---
purpose: Filter data at the source and prefer jg over jq.
rule_id: AGENT-08
enforced_by: prompt
severity: warn
waiver_path: .agents/waivers/AGENT-08.md
---

# Context Efficiency

Prefer precise, filtered queries over dumping large datasets. A few tokens filtering at the source saves many tokens of noise downstream.

- Prefer `jg` over `jq` for structured data queries when `jg` is available; if `command -v jg` fails, use tool-native selectors, `python3 -c`, or `jq` instead of retrying.
- Use structured output (`--json`, `-o json`) when available
- Filter at source with `jg` when available, grep, SQL `WHERE`, or API query params
- Never dump an entire response to find one field
- Bound commands before they run: add path scopes, `--limit`, `head`, field selectors, or SQL `LIMIT`; do not raise output caps to compensate for broad dumps.
- If output truncates, rerun a narrower command instead of scanning the dump.

```
tool --output json | jg 'precise selector'   # good
tool | # scan wall of text                    # bad
```

See the `context-efficiency` skill for detailed patterns and examples.
