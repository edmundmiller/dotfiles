---
name: jira-twg
description: Use the TWG CLI for explicit Jira issue reads, searches, queries, and mutations while minimizing returned context and preventing refetch or help loops. Do not use for Confluence, general Atlassian context, or TWG setup.
---

# Jira via TWG

Requires the `twg` and `jg` CLIs. Use `twg` only for Jira work. Do not install, update, authenticate, or repair it unless the user asks.

## Read narrowly

Choose one leaf command:

- Known keys, maximum 20 per batch: `twg jira workitem get KEY [KEY...] --fields summary,status,assignee`
- Exact criteria: `twg jira workitem query --jql '...' --limit 20`
- Fuzzy text: `twg jira workitem search '...' --limit 10 --fields summary,status,assignee`

Request only fields needed for the answer and batch known keys. Never use `--full`, `--comments`, or `--remote-links` unless that content is required. Never enumerate projects when an issue key or project is already known.

Append `--output json --output-summary auto --agent-fields @compact`. For query or search lists, use `@rows` only when key, summary, status, URL, and updated are sufficient; otherwise set explicit `data.issues.<field>` paths. Reserve `--output-summary stats` for output expected to exceed the bounded limits above. Use `--select` only when response paths are already known.

Use `stdout_inline` when present. Otherwise read `output_files.compact`; read only required paths from `output_files.stdout` when the compact file lacks a needed field.

## Bound scope and context

- Scope discovery to the requested project, saved filter, or explicit keys. Add relevant type/status/time constraints; never query all of Jira to answer a project question. Widen beyond the requested scope only with user authorization.
- Use as many bounded calls as needed to finish that scope. Default to 20 summary rows per page and at most 20 known keys per detail batch; larger inventories may use up to 100 summary rows written to disk. Follow pagination within the same scope, retaining cursors and pending keys. A capped page or failed read is not complete coverage.
- For recurring intake, compare a compact key/summary/status/updated index with the checkpoint first. Fetch descriptions, relevant comments and linked evidence only for changed reports and plausible duplicate matches. Use an overlapping time window with the Jira query timezone accounted for; checkpoint only successfully reviewed evidence.
- Reuse saved responses. Repeat a read only for missing fields, changed state, pagination, or write verification. Inspect response shape once, then extract needed paths locally; flatten rich-text bodies and filter comments by the checkpoint before returning them to context. Aim for at most 5,000 tokens per tool result. If output truncates, narrow the local extraction instead of refetching or printing the raw response again.
- Do not browse help first. After a rejected or genuinely unknown command, allow one `twg help describe "<exact leaf command>" | jg 'args | opts' --compact`; never list or search the full command catalog.
- Preserve stderr and exit status. Distinguish empty data from failure; never use `2>/dev/null` or translate an error into “no results.”
- Stop immediately on authentication or permission failure. After a contract error, use the one help allowance, make one corrected attempt, then stop and report the error.

## Write once

For an exact user-authorized mutation, read [the write contracts](./references/writes.md) before acting. They define current command shapes, the four-command ceiling, verification, and ambiguous-create handling. Do not improvise write flags.

## Maintain the contract

After a TWG upgrade, run `python3 ~/.agents/skills/jira-twg/scripts/check_contract.py --json`. It reads local help only and makes no Jira request. Do not run it during ordinary Jira work.
