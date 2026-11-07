---
name: rex
description: Use the rex CLI to manage Rex sessions, open tabs, arrange panes, run commands, inspect terminal output, and control connected Rex apps.
metadata:
  rex-stub: "2"
---
<!-- Installed by "rex skill setup". Remove it with "rex skill remove". -->

Run `rex __internal skill` and follow the guide it prints. The guide comes from
the installed Rex CLI, so it describes the commands available in that version.

## Temporary task panes

Treat one-shot tests, builds, checks, and probes as ephemeral. Record the server,
session, and returned block IDs when creating them. Preserve focus with
`--focus=false`.

For a synchronous one-shot command, use `rex run --wait` without `--keep-open`.
If an asynchronous job needs `--keep-open` so its result can be inspected, save
the output and check `process.last_exit`, then close only that completed block
with `rex block close -s SESSION BLOCK`. Close it after handling success or
failure; keeping evidence does not require keeping the pane. Apply the same
cleanup if Rex retains a failed synchronous command.

Keep running jobs in the process ledger until their results are handled. Leave
persistent servers, interactive agents, reviews, user-created panes, and anything
the user asked to keep open alone. Never sweep tabs by age or label, close a
whole tab containing unowned panes, or use cleanup to kill a running job.

## Older CLI

If the command fails, the installed Rex version predates the guide. Start with
`rex whoami --json`, then use `rex --help` and `rex COMMAND --help`.
