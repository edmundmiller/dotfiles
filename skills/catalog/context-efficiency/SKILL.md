---
name: context-efficiency
description: >
  Filter data at the source before it enters context. Use when querying APIs,
  CLIs, or databases where the full output would be large. Prefer structured
  output + jg when available, or python/tool-native selectors when not. Use jq
  only when jg cannot express the needed transformation. Trigger phrases:
  "find the entity for", "get the ID of", "which service handles", "what's the
  value of", or any time you'd otherwise dump a large dataset to find one thing.
license: MIT
---

# Context Efficiency: Filter at the Source

Every token of noise in context is a token the model spends navigating instead
of reasoning. Spend a few tokens on a precise query; save many on the backend.

## Decision tree

```
Does the tool support structured output? (--json, -o json, --format json)
├─ Yes → select fields with jg when available; if `command -v jg` fails, use tool-native selectors, python3 -c, or jq instead of retrying
└─ No → pre-filter with path scopes, grep, head, API params, or SQL LIMIT
```

## Structured-output patterns

```bash

# Select one field or path
tool -o json | jg 'precise.selector'


# Filter to the few fields needed
tool -o json | jg 'items matching condition -> id,name,status'


# Transform when selection is not enough
tool -o json | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["field"])'
```

## jq/python fallback patterns

Use these only when `jg` cannot express the needed transformation.

```bash
# python3 -c patterns
# Count by state
tool -o json | python3 -c "
import json, sys; d = json.load(sys.stdin)
from collections import Counter; print(Counter(x['state'] for x in d))
"

# Find matching entity
tool -o json | python3 -c "
import json, sys; d = json.load(sys.stdin)
print(next(x['entity_id'] for x in d if 'couch' in x['attributes'].get('friendly_name','').lower()))
"
```

## Bounded command output

Before running commands that can dump a tree, log, search result, build output,
or API collection, add a path scope, `--limit`, `head`, structured selector, or
SQL `LIMIT`. Do not raise output-token caps to compensate for an unbounded
command. If output truncates, rerun a narrower command instead of scanning the
dump.

## Oversized tool results

If a read, MCP call, or CLI returns "output too large" or saves overflow to a
file, do not retry the same broad request. Recover with a narrower query:

1. Re-run the source tool with tighter fields, date ranges, IDs, channel/project
   filters, or lower limits.
2. If the tool saved an overflow artifact, search or read only the relevant
   ranges from that saved file.
3. Prefer summaries or metadata endpoints before transcripts, full logs, Slack
   exports, calendar event lists, or issue dumps.

```bash
# ❌ broad transcript/log dump
tool get-transcript --id "$id"

# ✅ metadata or filtered content first
tool get-notes --id "$id"
tool search --query '"exact error" after:2026-01-01' --limit 5
```

## Tool-specific examples

### Home Assistant (hass-cli)

```bash
hass-cli -o json state list 'light.*' | jg 'entity_id,state,attributes.friendly_name'
hass-cli -o json area list | jg 'area_id,name'
hass-cli -o json device list | jg 'devices in kitchen -> id,name,area_id'
```

### GitHub CLI

```bash
gh pr checks 42 --json name,state | jg 'failed check names'
gh issue list --json number,title,labels --limit 30 | jg 'issues with bug label'
gh api repos/:owner/:repo/pulls --jq '.[].head.ref'
```

### Nix

```bash
nix eval .#packages --json | jg 'package names'
```

### Database

```sql
-- Always: WHERE + LIMIT over SELECT *
SELECT entity_id, state FROM states WHERE domain = 'light' ORDER BY last_changed DESC LIMIT 20;
```

## Anti-patterns

```bash
# ❌ dumps hundreds of entities to find one
hass-cli state list

# ✅ returns exactly what you need
hass-cli -o json state list 'light.*' | jg 'entity_id,state,attributes.friendly_name matching desk'

# ❌ loads full PR list into context
gh pr list

# ✅ targeted
gh pr list --json number,title --limit 30 | jg 'titles matching fix'
```
