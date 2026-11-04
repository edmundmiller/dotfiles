# hey subcommands

Nushell modules target the `nu` version in the repo dev shell. Syntax check:

```sh
nix develop --command nu --commands 'source bin/hey.d/common.nu; print ok'
```

Source the affected subcommand file too when it can be loaded independently.
For long Nix operations, `AGENT=1` selects concise progress and useful failure
output, including `--show-trace` on failure.

`hey check` delegates to `scripts/validation.py`, also used by CI. Do not add
another selector here. It runs in a disposable source snapshot. Credentials
resolved from `gh` belong only in Nix child environments, never output or Prek.
Changes to check selection also require
`python3 -m unittest tests/test_validation.py`; run `hey check bin/hey.d` for
the repository checks routed by the changed subcommand.
