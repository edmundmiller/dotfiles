# Context Efficiency

Prefer precise, filtered queries over dumping large datasets. A few tokens spent filtering at the source saves many tokens of noise downstream.

- Use structured output modes when available (`--output json`, `-o json`, `--format json`)
- Filter at the source with `jq`, `python3 -c`, `grep`, SQL `WHERE`, or API query params — before the data enters context
- Never dump an entire API response to find one field; write the query that returns only what you need

## Pattern

```
tool --output json | jq 'precise selector'
```

is always better than

```
tool | # scan wall of text to find the one value
```

## Examples

```bash
# HA: find a specific light's entity_id
hass-cli -o json state list 'light.*' \
  | jq -r '.[] | select(.attributes.friendly_name | test("couch"; "i")) | .entity_id'

# gh: get failing check names only
gh pr checks 42 --json name,state \
  | jq -r '.[] | select(.state == "FAILURE") | .name'

# jj: get the current change ID only
jj log -r @ --no-graph -T 'change_id ++ "\n"'

# SQL: don't SELECT *, add WHERE and LIMIT
psql -c "SELECT entity_id, state FROM states WHERE domain='light' LIMIT 20"
```
