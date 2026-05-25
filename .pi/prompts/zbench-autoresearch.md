/autoresearch Optimize my zsh startup performance using zsh-bench.

Objective:
Improve interactive zsh startup and responsiveness in this dotfiles repo using
romkatv/zsh-bench, while preserving behavior.

Primary benchmark:
Use the existing repo command:
hey zbench-save
or, for faster exploratory iterations:
hey zbench --iters 4

Primary metrics, lower is better:

- first_prompt_lag_ms
- first_command_lag_ms
- command_lag_ms
- input_lag_ms

Baseline files:

- benchmarks/zsh-bench/<host>.json
- benchmarks/zsh-bench/history/<host>.tsv

Files in scope:

- modules/shell/zsh/default.nix
- config/zsh/.zshrc
- config/zsh/.zsh_plugins.txt
- config/zsh/completion.zsh
- config/zsh/keybinds.zsh
- config/zsh/prompt.zsh
- bin/hey.d/zbench.nu only if the benchmark harness itself needs fixing

Important context:

- This is a Nix/nix-darwin/Home Manager dotfiles repo.
- zsh config content lives in config/zsh/ and is symlinked by modules/shell/zsh/default.nix.
- Do not edit unrelated dirty files.
- Use `br` for beads issue tracking if needed, not `bd`.
- Do not configure or use Anthropic API keys/models.
- Consider whether Home Manager's `programs.zsh.antidote.enable = true` can replace custom Antidote bootstrap logic.
- Antidote reference: https://github.com/mattmc3/antidote
- zsh-bench reference: https://github.com/romkatv/zsh-bench

Hypotheses to investigate:

1. Replace custom runtime Antidote discovery/globbing in `.zshrc` with Home Manager-managed Antidote if available.
2. Avoid sourcing Antidote itself on the fast path; source a precomputed static bundle only.
3. Ensure stale plugin-cache self-healing does not add measurable overhead to every shell startup.
4. Review compinit/completion setup for duplicated or mistimed initialization.
5. Keep deferred plugins deferred unless zsh-bench or behavior proves they need to load earlier.
6. Avoid changes that only improve benchmark numbers by disabling expected interactive features.

Correctness checks:
After promising changes, run:
nix develop --command nu --commands 'source bin/hey.d/common.nu; source bin/hey.d/zbench.nu; print ok'

Loop behavior:

- First, inspect current files and run a baseline.
- Make one small hypothesis-driven change at a time.
- Run zsh-bench after each change.
- Keep changes only if the improvement is meaningful and behavior is preserved.
- Re-run promising results to confirm they beat noise.
- Revert regressions.
- Record what was tried and why in autoresearch.md.
- At the end, summarize baseline vs best metrics, kept changes, rejected experiments, files changed, and exact commands run.
