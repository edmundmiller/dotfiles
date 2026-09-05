# hey subcommands

Nushell modules target the `nu` version in the repo dev shell. Syntax check:

```sh
nix develop --command nu --commands 'source bin/hey.d/common.nu; print ok'
```

Source the affected subcommand file too when it can be loaded independently.
For long Nix operations, `AGENT=1` selects concise progress and useful failure
output, including `--show-trace` on failure.

Completion hooks invoke this checkout's `bin/hey check --worktree`, not the
installed generation. Darwin checks expose the `gh` credential through
`NIX_CONFIG` only to Nix children; keep it out of output and Prek environments.
