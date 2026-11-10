---
name: hey-rebuilds
description: Runs `hey re` and other dotfiles rebuilds safely in a supervised terminal. Use before running `hey re`, `hey rebuild`, `hey switch`, `hey boot`, or `hey build`, or when diagnosing a failed rebuild.
---

# Running `hey` rebuilds

`hey re` needs a TTY for sudo and runs long. A piped bash call reports the
pipeline's exit status, not `hey`'s, and silently fakes success.

- Never run `hey re` through the bash tool.
- Run it as a supervised PTY process in the current terminal session (Rex or
  Herdr). When one already hosts you, use it; never launch a nested one.
- Read output and answer prompts through that process.
- Never enter a sudo password. Ask the user to answer the prompt, and stop the
  process if it cannot progress unattended.
- Never claim a rebuild succeeded without `hey`'s own unpiped exit status.
- Nix failure output is a cascade; `Reason: 1 dependency failed.` is noise.
  Diagnose from the first failing derivation, not the tail.
