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

| Metric                 | Threshold | What it means                             |
| ---------------------- | --------- | ----------------------------------------- |
| `first_prompt_lag_ms`  | 50ms      | Time to see prompt after opening terminal |
| `first_command_lag_ms` | 150ms     | Time until first command can execute      |
| `command_lag_ms`       | 10ms      | Delay between Enter and next prompt       |
| `input_lag_ms`         | 20ms      | Keystroke-to-screen latency               |

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

### Phase Timing Script

Don't guess — measure. Paste this into `zsh -c '...'` to time each phase of startup:

```zsh
zsh -c '
zmodload zsh/datetime
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"
export ZSH_CACHE="${ZSH_CACHE:-$XDG_CACHE_HOME/zsh}"
function _source { [[ -f "$1" ]] && source "$1"; }
function _cache {
  local cache_dir="$XDG_CACHE_HOME/zsh"; local cache_file="$cache_dir/$1.zsh"
  if [[ ! -f "$cache_file" ]] || [[ "$commands[$1]" -nt "$cache_file" ]]; then
    mkdir -p "$cache_dir"; "$@" > "$cache_file"; fi
  source "$cache_file"
}

t0=$EPOCHREALTIME
source $ZDOTDIR/.zshenv 2>/dev/null; t1=$EPOCHREALTIME
source $ZDOTDIR/config.zsh; t2=$EPOCHREALTIME
# ... add phases matching your .zshrc ...
source $ZDOTDIR/completion.zsh 2>/dev/null; t3=$EPOCHREALTIME
_source $ZDOTDIR/extra.zshrc; t4=$EPOCHREALTIME

printf "zshenv:     %4.0fms\n" $(( (t1-t0)*1000 ))
printf "config:     %4.0fms\n" $(( (t2-t1)*1000 ))
printf "completion: %4.0fms\n" $(( (t3-t2)*1000 ))
printf "extra:      %4.0fms\n" $(( (t4-t3)*1000 ))
printf "TOTAL:      %4.0fms\n" $(( (t4-t0)*1000 ))
'
```

Adapt phases to match the actual `.zshrc`. The gap between this total and `zsh-bench` is overhead from `/etc/zshrc` (nix-darwin generated) and deferred plugin loading.

To drill into `extra.zshrc`, time each `source` line individually — one slow alias file can dominate.

### Known Culprits (ranked by typical impact)

| Culprit                            | Typical cost  | Fix                                                                                                                                                                                |
| ---------------------------------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Redundant compinit**             | 2000-3000ms   | Ensure compinit runs exactly once. Check EOF of `.zshrc`, `/etc/zshrc`, and completion.zsh — easy to end up with 2+ calls. Use `compinit -C -d "$cache"` with 24h staleness check. |
| **Nix store globs**                | 200-400ms     | `for f in /nix/store/*foo*/*.zsh` is slow — thousands of dirs. Cache the resolved path to a file.                                                                                  |
| **Shell startup file scanning**    | 100-500ms     | Functions that `grep`/`sed` across many files at startup (e.g., fixing session files). Move to on-demand or a cron job.                                                            |
| **Uncached `eval "$(tool init)"`** | 40-100ms each | `brew shellenv`, `direnv hook zsh`, `fnm env`, `zoxide init zsh`, `entire completion zsh`. Use `_cache` pattern to write output to file, re-eval only when binary changes.         |
| **Double `brew shellenv`**         | 40-80ms       | nix-homebrew adds `eval "$(brew shellenv)"` to `/etc/zshrc`. If you handle it in `.zshenv`, set `enableZshIntegration = false` in nix-homebrew config.                             |
| **Plugin manager overhead**        | 10-40ms       | Antidote's `antidote load` does staleness checks. If static file exists, source it directly and skip antidote init entirely.                                                       |
| **Deferred plugins**               | 0ms startup   | antidote `kind:defer` is free at startup but zsh-bench won't detect `has_syntax_highlighting`/`has_autosuggestions`. This is fine.                                                 |

### The `_cache` Pattern

Central to fast startup. Already defined in `.zshrc`:

```zsh
function _cache {
  local cache_dir="$XDG_CACHE_HOME/zsh"
  local cache_file="$cache_dir/$1.zsh"
  if [[ ! -f "$cache_file" ]] || [[ "$commands[$1]" -nt "$cache_file" ]]; then
    mkdir -p "$cache_dir"
    "$@" > "$cache_file"
  fi
  source "$cache_file"
}

# Usage:
_cache zoxide init zsh        # instead of eval "$(zoxide init zsh)"
_cache direnv hook zsh        # instead of eval "$(direnv hook zsh)"
_cache entire completion zsh  # instead of source <(entire completion zsh)
```

Invalidates when the binary changes (`$commands[$1]` mtime check). Delete `~/.cache/zsh/*.zsh` to force regeneration.

### Replay Mode

Use `zsh-bench --iters 1 --scratch-dir /tmp/zbench-debug` then `dbg/replay --scratch-dir /tmp/zbench-debug` to watch what zsh-bench actually sees.

## Key Design Decisions

- Uses zsh-bench's **non-raw output** (median of 16 iterations) for stable numbers.
- **`--raw`** gives per-iteration arrays — useful for variance analysis but not default.
- Baselines stored as JSON for easy programmatic comparison.
- History stored as TSV for easy `column -t`, `awk`, or import into spreadsheets.
- Regression detection: flags changes > 20% or > 5ms (whichever is larger).
