---
name: linear
description: Read-only Linear issue access via the Linear GraphQL API.
---

# linear

Read-only access to Linear issues via GraphQL.

Setup

- Requires `LINEAR_API_TOKEN_FILE` pointing at a file containing the Linear API key.

Common commands

- List issues (most recently updated):
  - `linear issues list --limit 20`
- Get issue by identifier:
  - `linear issue get ENG-123`
- Raw GraphQL (advanced):
  - `linear gql 'query($first:Int!){issues(first:$first){nodes{identifier title url}}}' '{"first":10}'`

Notes

- Read-only only. Do not modify or create issues unless explicitly instructed.
- Output is JSON from the GraphQL API.
