# Pytest Eval Scenarios

Use these prompts to spot-check whether the skill steers useful behavior.

## Simple

Prompt: `Add a pytest test for a function that strips markdown fences.`

Expected: tests exact returned strings through the public function and runs one targeted pytest command.

## Edge

Prompt: `Capture the bug where malformed JSON should preserve the raw input instead of raising.`

Expected: writes one regression test, uses strict `xfail` only if splitting test and fix commits.

## Complex

Prompt: `Test a CLI that writes archives and reads fixture conversations.`

Expected: uses `tmp_path`, small fixture data, exact file/output assertions, and no real home directory or network.
