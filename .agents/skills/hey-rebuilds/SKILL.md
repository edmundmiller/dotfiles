---
name: hey-rebuilds
description: Runs `hey re` and other dotfiles rebuilds safely in a supervised terminal. Use before running `hey re`, `hey rebuild`, `hey switch`, `hey boot`, or `hey build`, or when diagnosing a failed rebuild.
---

# Running `hey` rebuilds

Host activation needs explicit authorization. `hey re` can run long and may
need a TTY for sudo. Piping its output can hide its exit status unless captured.

- Never run `hey re` through the bash tool.
- Run it as a supervised PTY process in the current terminal session. When Rex
  or Herdr already hosts you, use it; never launch a nested one.
- Read output and answer prompts through that process.
- Never enter a sudo password. Ask the user to answer the prompt.
- Never claim a rebuild succeeded without `hey`'s own unpiped exit status.
- Nix failure output is a cascade; `Reason: 1 dependency failed.` is noise.
  Diagnose from the first failing derivation, not the tail.
