# pi-rex

Pi knows which Rex terminal it is in, can read a pane into the conversation,
and reports its task state to Rex's tab headers and session picker.
Requires Pi 1.0 or newer and the separately installed Rex app and CLI.

## Use it

The dotfiles Pi settings include this package. To try the source without a
rebuild, start Pi inside a Rex terminal from this checkout:

```sh
pi -e ./packages/pi-packages/pi-rex/index.ts
```

Then try:

```text
/rex
/rex capture tests
Explain the failure in that pane and fix it.
```

Or ask Pi directly:

```text
Start the dev server beside you. Keep focus here and inspect its output for readiness.
Run the tests in a split, keep their output visible, and fix the failures.
```

These requests use Pi's existing Bash tool and the installed Rex guide.
The extension does not add an alternative command executor or bypass Bash hooks.
It does not install skills or change Rex configuration.

## Terminal awareness

Inside Rex, startup loads `rex skill show` with a five-second timeout. The guide
and `REX_SESSION`, `REX_BLOCK`, and `REX_SERVER` join the system prompt on every
run, including after compaction. The guide is cached until session start or
`/rex refresh`. A missing CLI or unreachable server does not prevent Pi starting.
`/rex` reports guide errors.

Outside Rex, there is no automatic CLI call or prompt injection. `/rex refresh`
opts the current Pi session in. Pi must discover and choose targets explicitly.
Only an explicit fork moves focus. The extension does not rename sessions. It instructs Pi to save
full IDs for created panes and close only its own panes when asked. These are
agent instructions, not an ownership-enforcement mechanism.

## Fork into a split or tab

While Pi is idle inside Rex, press `Ctrl+C`, then `f` for a right split, or
`Ctrl+C`, then `Shift+F` for a new tab. These bindings in `config/rex/init.lua`
send `Ctrl+Alt+F` and `Ctrl+Alt+T` to this extension. Your editor draft stays
in the original Pi session and is not submitted or copied to the fork.

Alternatively, run `/rex fork` and choose `split` or `tab`.
Use `/rex fork split` to open a pane on the right or `/rex fork tab` to open
a new tab without the picker. Rex focuses the new terminal.

The fork copies the currently selected conversation branch into a new session,
including your selection after `/tree` navigation. The original session stays
open and unchanged. Both sessions use the same working directory and files;
this does not create a Git worktree. Avoid concurrent edits to the same files.

Forking requires a saved conversation and refuses to run during an active
turn. It is unavailable inside nested tmux or screen sessions. If Rex
cannot confirm launch, the error includes the saved fork path. Check Rex before
retrying, or resume that copy with `pi --session <path>`.

## Bring a pane into the conversation

`/rex capture <pane ID or label>` reads a plain-text screen snapshot. Labels with
spaces work without quotes. An ambiguous target is an error, never a guess.
The capture enters the next model turn without starting one or interrupting an
active run. Ask your question after capturing.

Captures strip terminal controls and identify the output as untrusted data.
They retain the last 500 lines or 24 KiB. Larger captures get a private full copy
under the system temporary directory, linked in the message. This file persists
for later inspection until the OS or user removes it. Captures can contain
sensitive terminal text and become part of the Pi transcript. Choose panes
deliberately. There is no automatic background screen capture.

## Native Rex status

Pi emits [OSC 7501](https://www.superlogical.com/rex/docs/build/program-status.md):

| Pi event                           | Rex status                              |
| ---------------------------------- | --------------------------------------- |
| Session starts                     | Idle                                    |
| Agent runs or executes a tool      | Working                                 |
| Blocking confirmation dialog       | Blocked, permission                     |
| Other blocking extension UI prompt | Blocked, question                       |
| Prompt closes                      | Working or idle                         |
| Agent fully settles                | Done, error, or idle after cancellation |
| Reload or session replacement      | Clear this Pi process's record          |

Completion waits for `agent_settled`, so retries and automatic continuation do
not produce premature done indicators. Done and error records survive a normal
quit. Reports use a process-specific ID and never clear other programs' records.
Messages omit commands, arguments, prompt titles, and model output.

Pi 1.3 exposes cancellation at final settlement. On Pi 1.0, the extension uses
the run's abort signal and a skipped settlement hook. Cancellation during another
extension's settlement hook can still appear as done on that older version.

Status emits only in Pi's TUI with a real stdout terminal and both Rex location
variables. RPC, JSON, text output, redirected stdout, tmux, and screen get no OSC
bytes. Blocking status depends on Pi's UI prompt events; terminal subprocess
prompts and custom tools that do not use Pi's prompt API cannot be detected.

## Development

```sh
bun install --frozen-lockfile  # from packages/pi-packages
bun run --cwd pi-rex typecheck
bun run --cwd pi-rex test
```

Tests cover lifecycle reports, quiet non-TUI modes, guidance injection, capture
targeting, truncation, failures, cancellation during session replacement, and
forking the selected branch without changing the source session.
Native Rex indicators still need a Mac smoke test. Run Pi in an unfocused Rex
tab, start a task, exercise a permission prompt, finish a response, and interrupt
a second task. Confirm working, blocked, done, and idle states in Rex.

References:

- [Pi extensions](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md)
- [Rex agents](https://www.superlogical.com/rex/docs/automate/agent-skill.md)
- [Rex CLI](https://www.superlogical.com/rex/docs/automate/cli.md)
- [Rex shell scripting](https://www.superlogical.com/rex/docs/automate/shell-scripting.md)
