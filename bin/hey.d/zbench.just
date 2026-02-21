# zsh-bench benchmarking commands

import 'common.just'

_zbench_dir := FLAKE_DIR / "benchmarks" / "zsh-bench"
_zbench_report := FLAKE_DIR / "bin" / "zbench-report"

# Run zsh-bench and display results (default)
zbench *args: (_zbench "run" args)

# Run zsh-bench and save result as new baseline
[group('bench')]
zbench-save *args: (_zbench "save" args)

# Run zsh-bench and compare against saved baseline
[group('bench')]
zbench-compare *args: (_zbench "compare" args)

# Check if zsh performance exceeds thresholds (for git bisect)
[group('bench')]
zbench-check *args: (_zbench "check" args)

# Show saved baseline
[group('bench')]
zbench-baseline:
    @cat "{{_zbench_dir}}/{{flake_host}}.json" 2>/dev/null || echo "No baseline saved. Run: hey zbench-save"

# Show benchmark history
[group('bench')]
zbench-history:
    @cat "{{_zbench_dir}}/history/{{flake_host}}.tsv" 2>/dev/null || echo "No history. Run: hey zbench-save"

_zbench mode *args:
    #!/usr/bin/env bash
    set -euo pipefail

    # Find zsh-bench (installed via nix, falls back to repo root)
    zbench=$(command -v zsh-bench || echo "{{FLAKE_DIR}}/zsh-bench")
    echo "==> Running zsh-bench (16 iterations)..."
    raw=$("$zbench" {{args}})

    # Feed to report script
    echo "$raw" | "{{_zbench_report}}" \
        --mode "{{mode}}" \
        --host "{{flake_host}}" \
        --dir "{{_zbench_dir}}" \
        --git-rev "$(git -C "{{FLAKE_DIR}}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
