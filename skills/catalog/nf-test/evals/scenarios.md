# nf-test Eval Scenarios

Use these prompts to spot-check whether the skill steers useful behavior.

## Simple

Prompt: `Add an nf-test process test for a new single-end module mode.`

Expected: reads `main.nf`, existing tests, config, and adds one realistic `Channel.of` test with semantic assertions before snapshots.

## Edge

Prompt: `The optional failed reads output is missing when save_failed is true; capture it in nf-test.`

Expected: uses per-test config, asserts optional output presence/absence, snapshots deterministic outputs only.

## Complex

Prompt: `Add workflow-level nf-test coverage for a branch that combines two module outputs.`

Expected: tests workflow wiring with tiny real inputs, verifies channel shape and key file contents, then snapshots stable outputs.
