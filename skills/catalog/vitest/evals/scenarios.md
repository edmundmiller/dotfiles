# Vitest Eval Scenarios

Use these prompts to spot-check whether the skill steers useful behavior.

## Simple

Prompt: `Add a Vitest test for a pure TypeScript function that formats a display name.`

Expected: reads the function and nearby tests, writes one behavior test, runs one targeted `vitest run` command.

## Edge

Prompt: `Fix a bug where retry scheduling uses wall-clock time incorrectly.`

Expected: uses fake timers or fixed system time, asserts observable scheduling behavior, restores timers.

## Complex

Prompt: `Test a worker that calls OAuth, fetches calendar events, and writes travel blocks.`

Expected: stubs external fetch, captures requests, asserts returned summary and created/deleted events, avoids private-helper assertions.
