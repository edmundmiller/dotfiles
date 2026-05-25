# Zsh startup autoresearch

## Baseline

The installed `hey zbench --iters 4` failed before running zsh-bench because Nushell treated `--iters` as a flag for the `hey zbench` custom command. For exploratory shell-performance runs I used direct `zsh-bench --iters 4` until fixing the repo-local harness.

Direct baseline (`zsh-bench --iters 4`):

| metric | ms |
| --- | ---: |
| first_prompt_lag_ms | 27.894 |
| first_command_lag_ms | 689.543 |
| command_lag_ms | 175.074 |
| input_lag_ms | 4.986 |
| exit_time_ms | 334.448 |

Repo-local harness after fix (`./bin/hey zbench --iters 4`, confirmation run):

| metric | ms |
| --- | ---: |
| first_prompt_lag_ms | 28.6 |
| first_command_lag_ms | 681.0 |
| command_lag_ms | 168.5 |
| input_lag_ms | 5.2 |
| exit_time_ms | 325.7 |

The repo-local harness numbers are effectively the same performance band as the direct baseline; the kept change is a harness correctness fix, not a zsh startup optimization.

## Kept changes

1. `bin/hey.d/zbench.nu`: mark zbench subcommands `def --wrapped ... [...args]` so flags like `--iters 4` are forwarded to zsh-bench instead of rejected by Nushell command parsing.
   - Validated with `./bin/hey zbench --iters 4`.
   - Note: the already-installed `hey` on `PATH` still points at the previous generation until rebuild, so repo-local `./bin/hey` was used for validation.

## Rejected experiments

1. Simplify Antidote static-bundle health checking and remove duplicate bun completion source.
   - Result: first_prompt/first_command did not improve; discarded.
2. Remove duplicate unconditional bun completion source only.
   - Result: no meaningful improvement; discarded.
3. Simplify `_cache` to avoid command mtime checks for cached command-generated snippets.
   - Result: no meaningful improvement; discarded.
4. Defer fzf shell integration via `kind:defer`.
   - Result: some secondary metrics improved slightly, but first prompt lag regressed and fzf keybindings may become delayed; discarded.

## Commands run

- `zsh-bench --iters 4`
- `ZDOTDIR=$PWD/config/zsh ZSH_CACHE=$HOME/.cache/zsh zsh-bench --iters 4`
- `./bin/hey zbench --iters 4`
- `nix develop --command nu --commands 'source bin/hey.d/common.nu; source bin/hey.d/zbench.nu; print ok'`
- Several experiment-specific bundle regenerations with `antidote bundle < config/zsh/.zsh_plugins.txt >| ~/.cache/zsh/.zsh_plugins.zsh`; the bundle was regenerated from the final checked-in plugin file after discarded experiments.
