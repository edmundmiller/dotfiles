# Context Efficiency

Prefer precise, filtered queries over dumping large datasets. A few tokens filtering at the source saves many tokens of noise downstream.

- Use structured output (`--json`, `-o json`) when available
- Filter at source with `jq`, `grep`, SQL `WHERE`, or API query params
- Never dump an entire response to find one field

```
tool --output json | jq 'precise selector'   # good
tool | # scan wall of text                    # bad
```

See the `context-efficiency` skill for detailed patterns and examples.
