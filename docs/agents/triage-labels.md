---
purpose: Map triage roles to this repository's Beads label vocabulary.
applies_to: Triage, issue creation, and state changes through br.
entrypoint: Use these mapped labels with br when changing triage state.
verification: Run br show <issue-id> and confirm labels and issue state.
update_when: Triage vocabulary or Beads label names change.
---

# Triage labels

The engineering skills use five canonical triage roles. This repository uses
the same label strings:

| Role              | Beads label       | Meaning                                 |
| ----------------- | ----------------- | --------------------------------------- |
| `needs-triage`    | `needs-triage`    | Maintainer needs to evaluate the issue  |
| `needs-info`      | `needs-info`      | Waiting on the reporter for information |
| `ready-for-agent` | `ready-for-agent` | Fully specified for an agent            |
| `ready-for-human` | `ready-for-human` | Requires human implementation           |
| `wontfix`         | `wontfix`         | Will not be actioned                    |

Apply a label with `br label add --label <label> <issue-id>` and verify the
result with `br show <issue-id>`.
