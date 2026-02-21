---
name: context-efficiency
description: >
  Filter data at the source before it enters context. Use when querying APIs,
  CLIs, or databases where the full output would be large. Prefer structured
  output + jq/python filtering over dumping and scanning. Trigger phrases:
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
├─ Yes → use it, then pipe to jq or python3 -c
└─ No → use grep/awk to pre-filter, or hit the raw API with query params
```

## jq patterns

```bash
# Get one field from an array of objects
tool -o json | jq -r '.[0].field'

# Filter array by condition
tool -o json | jq '[.[] | select(.state == "on")]'

# Case-insensitive name search
tool -o json | jq -r '.[] | select(.attributes.friendly_name | test("couch"; "i")) | .entity_id'

# Count by group
tool -o json | jq 'group_by(.state) | map({state: .[0].state, count: length})'

# Pluck two fields
tool -o json | jq -r '.[] | [.entity_id, .state] | @tsv'
```

## python3 -c patterns

```bash
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

## Tool-specific examples

### Home Assistant (hass-cli)

```bash
hass-cli -o json state list 'light.*' | jq -r '.[] | select(.state=="on") | .entity_id'
hass-cli -o json area list | jq -r '.[] | [.area_id, .name] | @tsv'
hass-cli -o json device list | jq '[.[] | select(.area_id == "kitchen")]'
```

### GitHub CLI

```bash
gh pr checks 42 --json name,state | jq -r '.[] | select(.state=="FAILURE") | .name'
gh issue list --json number,title,labels | jq '[.[] | select(.labels[].name == "bug")]'
gh api repos/:owner/:repo/pulls --jq '.[].head.ref'
```

### Nix

```bash
nix eval .#nixosConfigurations.nuc.config.environment.systemPackages --json | jq -r '.[].name' | grep hass
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
hass-cli -o json state list 'light.*' | jq -r '.[] | select(.attributes.friendly_name | test("desk"; "i")) | .entity_id'

# ❌ loads full PR list into context
gh pr list

# ✅ targeted
gh pr list --json number,title --jq '.[] | select(.title | test("fix"; "i"))'
```
