# Pi Command Policy Bridge Tests

These tests are a living spec for `pi-command-policy-bridge`.

We are trying to dogfood this package in our own Pi workflow: the tests should
prove that the package blocks commands we do not want agents to run, while still
allowing the safe paths we expect agents to use.

Treat each regression test like an antibody in an organism, or a T cell: when we
hit a bug in the permission gate, capture it here so the same failure cannot
silently come back later.

## What Belongs Here

- Bugs we have already hit in real agent runs.
- Commands that must be denied, such as direct nix rebuilds or `git commit --no-verify`.
- Commands that must stay allowed, such as the blessed wrapper command `hey re`.
- Edge cases around command extraction from extension tools, not just direct
  `bash` tool invocations.

## Maintenance Rule

When changing the package or `config/pi/pi-permissions.jsonc`, update these tests
as the executable documentation of the intended behavior.
