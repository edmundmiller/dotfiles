---
name: zbench
description: >
  Benchmark interactive zsh performance with zsh-bench and track regressions.
  Use when benchmarking shell startup, comparing zsh latency after config
  changes, investigating slow shell, or running git bisect on performance.
  Trigger phrases: "benchmark zsh", "shell is slow", "zbench", "zsh-bench",
  "shell startup time", "profile zsh", "zsh performance".
---

# zsh-bench Integration

Proper benchmarking of interactive zsh using [romkatv/zsh-bench](https://github.com/romkatv/zsh-bench). Measures real user-visible latency, NOT `time zsh -lic exit` (which is meaningless).

## Commands

```bash
hey zbench              # Run + display with threshold indicators (auto-compares if baseline exists)
hey zbench-save         # Run + save as baseline + append history
hey zbench-compare      # Run + explicit diff against baseline
hey zbench-check        # Exit non-zero if over threshold (for git bisect)
hey zbench-baseline     # Show saved baseline (no run)
hey zbench-history      # Show TSV history
```

All commands accept extra zsh-bench args: `hey zbench --iters 4` for quick runs.

## Metrics & Thresholds

From romkatv's blind perception study — values at or below threshold are indistinguishable from zero:

| Metric | Threshold | What it means |
|--------|-----------|---------------|
| `first_prompt_lag_ms` | 50ms | Time to see prompt after opening terminal |
| `first_command_lag_ms` | 150ms | Time until first command can execute |
| `command_lag_ms` | 10ms | Delay between Enter and next prompt |
| `input_lag_ms` | 20ms | Keystroke-to-screen latency |

Indicators: 🟢 ≤50% (headroom) · 🟡 ≤100% (imperceptible) · 🟠 ≤200% (noticeable) · 🔴 >200% (sluggish)

`exit_time_ms` is shown but **not** used for thresholds — it doesn't measure interactive performance.

## Git Bisect Workflow

Find which commit made the shell slow:

```bash
git bisect start
git bisect bad HEAD
git bisect good <known-good-commit>
git bisect run hey zbench-check
```

`zbench-check` exits non-zero when any metric exceeds its threshold.

## File Layout

```
benchmarks/zsh-bench/
├── <Host>.json              # Current baseline per host
└── history/
    └── <Host>.tsv           # Append-only history (timestamp, git_rev, metrics)
packages/zsh-bench.nix       # Nix package (romkatv/zsh-bench with internal/ helpers)
bin/hey.d/zbench.just         # Hey recipes
bin/zbench-report             # Python — parse, compare, format results
```

Baselines are per-host (`MacTraitor-Pro.json`, `Seqeratop.json`) because hardware varies.

## Typical Workflow

```bash
# 1. Establish baseline on a clean build
hey zbench-save

# 2. Make zsh config changes
vim config/zsh/.zshrc
hey rebuild

# 3. Check for regressions
hey zbench                    # Shows comparison vs baseline

# 4. If satisfied, update baseline
hey zbench-save
```

## Debugging Slow Startup

If `first_command_lag_ms` is high, common culprits:

- **compinit** — `autoload -Uz compinit && compinit` is expensive. Check if called multiple times.
- **Deferred plugins** — antidote `kind:defer` plugins load asynchronously; zsh-bench may not detect `has_syntax_highlighting`/`has_autosuggestions` if deferred.
- **direnv** — hook runs on every prompt, adds to command_lag.
- **Plugin managers** — antidote caching helps but initial bundle generation is slow.
- **eval "$(tool init zsh)"** — each eval forks a subprocess. Cache output to a file instead (see zoxide caching pattern in `.zshrc`).

Use `zsh-bench --iters 1 --scratch-dir /tmp/zbench-debug` then `dbg/replay --scratch-dir /tmp/zbench-debug` to watch what zsh-bench actually sees.

## Key Design Decisions

- Uses zsh-bench's **non-raw output** (median of 16 iterations) for stable numbers.
- **`--raw`** gives per-iteration arrays — useful for variance analysis but not default.
- Baselines stored as JSON for easy programmatic comparison.
- History stored as TSV for easy `column -t`, `awk`, or import into spreadsheets.
- Regression detection: flags changes > 20% or > 5ms (whichever is larger).
