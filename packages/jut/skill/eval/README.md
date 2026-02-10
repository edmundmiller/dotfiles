# jut Skill Eval Harness

Eval harness for testing that AI agents correctly follow the jut skill when performing jj version control tasks. Supports both Claude Code and Codex.

## What it tests

- Agent uses `jut` (not raw `jj`) for mutations
- `jut status --json` always precedes mutations
- Mutation commands include `--json --status-after`
- No redundant `jut status` after `--status-after`
- Agent drops to raw `jj` for interactive commands (split, resolve, diffedit)
- Correct command sequencing (branch before commit, status before mutation)
- Correct use of `rub` primitive for amend/discard operations
- Agent uses `jut pr` instead of raw `gh pr`

## Prerequisites

- `jut` binary built (`cargo build` in `packages/jut/`)
- `jj` installed and available
- Node.js >= 20
- promptfoo (`npx promptfoo`)

**For Claude evals:**

- Claude Code CLI >= 1.0.88

**For Codex evals:**

- Codex CLI >= 0.99.0

## Setup

```bash
cd packages/jut/skill/eval
pnpm install --ignore-workspace
```

## Run evals

```bash
# Both providers (default)
pnpm run eval

# Claude only
pnpm run eval:claude

# Codex only
pnpm run eval:codex

# Repeat 3x for statistical significance
pnpm run eval:repeat

# View results
pnpm run view
```

## Environment Variables

| Variable                      | Default            | Description                                                            |
| ----------------------------- | ------------------ | ---------------------------------------------------------------------- |
| `JUT_EVAL_AGENT`              | `claude`           | Which agent to run (`claude` or `codex`)                               |
| `JUT_EVAL_JUT_BIN`            | `target/debug/jut` | Path to jut binary                                                     |
| `JUT_EVAL_CLAUDE_BIN`         | `claude`           | Path to Claude CLI                                                     |
| `JUT_EVAL_CODEX_BIN`          | `codex`            | Path to Codex CLI                                                      |
| `JUT_EVAL_MODEL`              | auto               | Model override (default: `claude-sonnet-4-5-20250929` / `gpt-5-codex`) |
| `JUT_EVAL_AUTH_MODE`          | `auto`             | Auth: `auto`, `local` (account), `api` (API key)                       |
| `JUT_EVAL_ANTHROPIC_API_KEY`  | —                  | API key for Claude (api mode)                                          |
| `JUT_EVAL_RUNNER_TIMEOUT_MS`  | `180000`           | Timeout per test case (ms)                                             |
| `JUT_EVAL_KEEP_FIXTURES`      | `0`                | Set to `1` to preserve fixture directories                             |
| `JUT_EVAL_MIN_CLAUDE_VERSION` | `1.0.88`           | Minimum Claude CLI version                                             |
| `JUT_EVAL_MIN_CODEX_VERSION`  | `0.99.0`           | Minimum Codex CLI version                                              |

## Architecture

```
eval/
├── promptfooconfig.yaml           # Test scenarios + provider config
├── providers/
│   ├── jut-integration.ts         # Main provider: fixture lifecycle, JSONL parsing,
│   │                              #   command trace extraction, repo state capture
│   ├── claude-local.sh            # Claude Code runner (--output-format stream-json)
│   └── codex-local.sh             # Codex runner (exec --json)
├── assertions/
│   └── jut-assertions.ts          # Command trace analysis functions
├── setup-fixture.sh               # Creates disposable jj repos with skill installed
├── package.json
└── tsconfig.json
```

### Provider Flow

1. `jut-integration.ts` creates a disposable jj repo via `setup-fixture.sh`
2. Runs setup_commands (create test files, prior commits)
3. Invokes agent via `claude-local.sh` or `codex-local.sh`
4. Parses JSONL output → extracts command traces
5. Captures repo state with `jut status --json`
6. Returns structured result for assertions
7. Cleans up fixture (unless `keep_fixtures: true`)

### Command Trace Extraction

The provider parses agent output (JSONL from both Claude and Codex formats) to build a list of bash commands the agent executed. Assertions then verify:

- Command ordering (status before mutations)
- Flag presence (`--json`, `--status-after`)
- Tool choice (`jut` vs `jj` vs `gh`)
- No redundant calls

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
| PR flow              | Uses `jut pr`, not raw `gh pr`                                    |
| Pull flow            | Uses `jut pull` with proper flags                                 |

## Debugging

```bash
# Keep fixture directories for inspection
JUT_EVAL_KEEP_FIXTURES=1 pnpm run eval

# Or in config:
# providers[].config.keep_fixtures: true

# Run single test
npx promptfoo eval --filter-description "Basic commit"

# Verbose promptfoo output
npx promptfoo eval --verbose
```
