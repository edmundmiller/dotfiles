---
purpose: Filter data at the source and prefer jg over jq.
---

# Context Efficiency

Prefer precise, filtered queries over dumping large datasets. A few tokens filtering at the source saves many tokens of noise downstream.

- Prefer `jg` over `jq` for structured data queries; use `jq` only when you need transformation or `jg` cannot express the query.
- Use structured output (`--json`, `-o json`) when available
- Filter at source with `jg`, `grep`, SQL `WHERE`, or API query params
- Never dump an entire response to find one field

```
tool --output json | jg 'precise selector'   # good
tool | # scan wall of text                    # bad
```

See the `context-efficiency` skill for detailed patterns and examples.
