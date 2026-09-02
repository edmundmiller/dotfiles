---
purpose: Provide exact bounded TWG Jira write contracts.
applies_to: User-authorized Jira creates, updates, and transitions.
entrypoint: Read from the jira-twg skill before a mutation.
verification: Read back only the changed fields after a successful write.
update_when: TWG Jira write flags or output contracts change.
---

# Jira write contracts

These commands were checked against TWG 1.2.7. If one is rejected, use the skill's single filtered help allowance; never browse the command catalog.

The maximum workflow is one minimal pre-read, one optional metadata or transition lookup, one mutation, and one verification. Preserve stderr and exit status.

## Create

Replace uppercase placeholders. `--space` accepts a Jira project key. Pass substituted values as separate argv entries. If displaying a shell command, shell-quote every substituted value. Inside JQL string literals, escape `\` as `\\` and `"` as `\"` before shell-quoting the complete JQL argument.

```sh
twg jira workitem create --space PROJECT_KEY --type TYPE --summary 'SUMMARY' --yes --output json --output-summary auto --agent-fields data.success,data.issue.key
```

On success, retain the returned key and verify it once with `jira workitem get` using only created fields. Treat the create call as non-repeatable: verify it, never recreate it.

If the response is ambiguous and has no key, never rerun create. Replace the placeholders below, quoting a multiword type, and run this one verification:

```sh
twg jira workitem query --jql 'project = PROJECT_KEY AND issuetype = TYPE AND creator = currentUser() AND summary ~ "\"UNIQUE SUMMARY\"" AND created >= -10m ORDER BY created DESC' --limit 2 --output json --output-summary auto --agent-fields @rows
```

Only one candidate with the exact summary proves creation. Otherwise report the create as ambiguous.

## Update or transition

Use the high-level update for a target status:

```sh
twg jira workitem update --id KEY --status 'Done' --output json --output-summary auto --agent-fields data.success,data.issue.key
```

When a specific transition or transition fields are required, omit `--transition-id` for the one allowed read-only discovery, then perform the mutation:

```sh
twg jira workitem transition --id KEY --output json --output-summary auto
twg jira workitem transition --id KEY --transition-id ID_OR_NAME --output json --output-summary auto --agent-fields data.success,data.issue.key
```

After success, verify only changed fields with one `jira workitem get`. Stop immediately on authentication or permission failure. Never retry an ambiguous write. For a non-create write, verify changed fields once; if the intended state is not proven, report ambiguity.
