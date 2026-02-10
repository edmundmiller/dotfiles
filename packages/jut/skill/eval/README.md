# jut Skill Eval Harness

Eval harness for testing that AI agents correctly follow the jut skill when performing jj version control tasks.

## What it tests

- Agent uses `jut` (not raw `jj`) for mutations
- `jut status --json` always precedes mutations
- Mutation commands include `--json --status-after`
- No redundant `jut status` after `--status-after`
- Agent drops to raw `jj` for interactive commands (split, resolve, diffedit)
- Correct command sequencing (branch before commit, status before mutation)
- Correct use of `rub` primitive for amend/discard operations

## Prerequisites

- `jut` binary built (`cargo build` in `packages/jut/`)
- `jj` installed and available
- Claude Code CLI installed (for Claude runner)
- Node.js >= 20
- promptfoo (`npx promptfoo`)

## Setup

```bash
cd packages/jut/skill/eval
pnpm install --ignore-workspace
```

## Run evals

```bash
# All scenarios
pnpm run eval

# View results
pnpm run view
```

## Files

- `promptfooconfig.yaml` — Test scenarios and assertion wiring
- `assertions/jut-assertions.ts` — Assertion functions (command trace analysis)
- `providers/claude-local.sh` — Claude Code runner wrapper
- `setup-fixture.sh` — Creates disposable jj repos with skill installed

## Scenarios

| Test                 | What it verifies                                                  |
| -------------------- | ----------------------------------------------------------------- |
| Basic commit         | status → commit with `--json --status-after`, no redundant status |
| Branch workflow      | branch creation before commit                                     |
| Ordering             | status always precedes mutations                                  |
| Rub amend            | `jut rub <file> <rev>` with proper flags                          |
| Discard              | `jut discard` or `jut rub <target> zz`                            |
| Squash               | `jut squash` with status-first pattern                            |
| Interactive fallback | Uses `jj split` (not `jut split`)                                 |
| Stacked branch       | `jut branch --stack` for dependent work                           |

## Debugging

Set `keep_fixtures: true` in `promptfooconfig.yaml` under `providers[].config` to preserve fixture directories.

```bash
JUT_EVAL_KEEP_FIXTURES=1 pnpm run eval
```
