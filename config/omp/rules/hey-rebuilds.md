---
name: hey-rebuilds
description: Run hey rebuilds inside the current Herdr session, never as piped bash calls.
stable: true
condition: "(?m)(?:^|[;&|]\\s*)(?:sudo\\s+(?:-\\S+\\s+)*)?hey\\s+(?:re|rebuild|switch|boot|build)\\b"
scope: "tool:bash"
---

## Running `hey` rebuilds

`hey re` needs a TTY for sudo and is long-running. A piped bash invocation
reports the pipeline's exit status, not `hey`'s, and silently fakes success.

- Never run `hey re` through the bash tool.
- On Seqeratop, run it in the current Herdr session. When `HERDR_ENV=1` that
  session already exists; use it and never launch a nested one.
- Start it as a supervised PTY process owned by that session, then read output
  and answer prompts through the process.
- Never enter a sudo password. Ask the user to answer the prompt, and stop the
  process if it cannot progress unattended.
- Never claim a rebuild succeeded without `hey`'s own unpiped exit status.
- Nix failure output is a cascade; `Reason: 1 dependency failed.` is noise.
  Diagnose from the first failing derivation, not the tail.
