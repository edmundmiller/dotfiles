# Shared Nushell task logic

Nushell modules target the `nu` version in the repo dev shell. Syntax check:

```sh
nix develop --command nu --commands 'use bin/hey.d/.lib/common.nu *; print ok'
```

Executable entrypoints live in `bin/hey.d/`; this directory holds shared helpers.
For long Nix operations, `AGENT=1` selects concise progress and useful failure
output, including `--show-trace` on failure.

`hey check` delegates to `scripts/validation.py`, also used by CI. Do not add
another selector here. It runs in a disposable source snapshot. Credentials
resolved from `gh` belong only in Nix child environments, never output or Prek.
Changes to check selection also require
`python3 -m unittest tests/test_validation.py tests/test_mise_tasks.py`;
run `hey check bin/hey.d` for the affected repository checks.
