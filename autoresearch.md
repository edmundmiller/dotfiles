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

## 2026-05-25 command-lag hook profiling

Baseline rerun (`./bin/hey zbench --iters 4`):

| metric | ms |
| --- | ---: |
| first_prompt_lag_ms | 35.7 |
| first_command_lag_ms | 895.4 |
| command_lag_ms | 204.4 |
| input_lag_ms | 5.3 |
| exit_time_ms | 424.2 |

Hook inventory (`ZDOTDIR=$PWD/config/zsh ZSH_CACHE=$HOME/.cache/zsh zsh -lic 'print -l ...'`):

- `precmd_functions`: `_direnv_hook`, `_mise_hook_precmd`, `_p9k_do_nothing`, `_p9k_precmd_first`, `_ghostty_deferred_init`, `_p9k_precmd`, `precmd_vcs_info`
- `preexec_functions`: `_p9k_preexec1`, `_p9k_preexec2`
- `chpwd_functions`: `_direnv_hook`, `_mise_hook_chpwd`, `__am_hook`, `__zoxide_hook`

Manual timing showed the dominant per-prompt cost was `precmd_vcs_info` from `rkh/zsh-jj`:

| hook/command | observed cost |
| --- | ---: |
| `precmd_vcs_info` | first run 563.85 ms, then ~130 ms |
| direct `vcs_info` | ~201.15 ms avg |
| `_direnv_hook` / `direnv export zsh` | ~6-11 ms steady, one cold 73 ms outlier |
| `_mise_hook_precmd` | ~10-18 ms |
| `_ghostty_deferred_init` | ~16-22 ms after setup |
| `_p9k_precmd` | ~1.5-2.4 ms after first run |
| `jj` quick prompt call | ~27.45 ms |
| `__zoxide_hook` direct add | ~13.95 ms |
| `__am_hook` direct sync | ~4.46 ms |

Kept experiment: remove `rkh/zsh-jj` from `config/zsh/.zsh_plugins.txt`. The active prompt already has its own async `jj` segment in `config/zsh/prompt.zsh`, so `zsh-jj` only adds an unused `vcs_info` precmd hook in this setup.

After regenerating `~/.cache/zsh/.zsh_plugins.zsh` from the edited plugin file with Antidote 1.10.3, hook inventory no longer includes `precmd_vcs_info` and P10k remains loaded.

Confirmation benchmark (`./bin/hey zbench --iters 4`):

| metric | ms |
| --- | ---: |
| first_prompt_lag_ms | 38.8 |
| first_command_lag_ms | 533.6 |
| command_lag_ms | 51.4 |
| input_lag_ms | 5.7 |
| exit_time_ms | 440.7 |

Best confirmation run for same change:

| metric | ms |
| --- | ---: |
| first_prompt_lag_ms | 37.3 |
| first_command_lag_ms | 515.6 |
| command_lag_ms | 39.7 |
| input_lag_ms | 5.7 |
| exit_time_ms | 401.4 |

Result: command lag improved from ~204.4 ms to 39.7-51.4 ms. This does not reach the 10 ms imperceptible threshold, but removes the largest confirmed prompt-loop cost without dropping the active async jj prompt.

Additional kept hardening: `_antidote_static_is_healthy` now invalidates the generated static bundle when `config/zsh/.zsh_plugins.txt` is newer. Without this, removing `rkh/zsh-jj` from the source plugin list may leave the old cached bundle active until manual cache deletion/regeneration.

Validation after cache invalidation change (`./bin/hey zbench --iters 4`):

| metric | ms |
| --- | ---: |
| first_prompt_lag_ms | 37.9 |
| first_command_lag_ms | 532.4 |
| command_lag_ms | 54.1 |
| input_lag_ms | 5.4 |
| exit_time_ms | 429.6 |


---

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

# nix-direnv cache autoresearch: dotfiles-d6fc

## Finding

nix-direnv is installed and effective for dotfiles. The slow path is cache miss
or cache renewal, not lack of nix-direnv.

## Evidence

- `~/.config/direnv/direnvrc` is a home-manager symlink into the Nix store.
- `config/direnv/direnvrc` sources nix-direnv from `~/.nix-profile/share/nix-direnv/direnvrc` or `/run/current-system/sw/share/nix-direnv/direnvrc`.
- `modules/shell/direnv.nix` enables home-manager direnv and `nix-direnv.enable = true`.
- `.envrc` calls `use flake`.
- After `direnv allow .`, first load logged missing profile/rc and renewed cache.
- Warm loads logged `nix-direnv: Using cached dev shell`.
- `.direnv/flake-profile-a5d5b61aa8a61b7d9d765e1daf971a9a578f1cfa` points at `/nix/store/q4izzw6gvkjgynl2q0jx9k0fvd1ci188-nix-shell-env`.
- `nix-store --query --roots` shows this worktree's `.direnv/flake-profile-*` as a GC root.

## Timings

- cold/missing profile: `direnv exec . true` took ~14.00s and renewed cache.
- warm cache hits: `direnv exec . true` took ~0.19s, ~0.19s, ~0.20s; later ~0.19s.

## Invalidation causes observed/expected

nix-direnv watches `.envrc`, `~/.config/direnv/direnvrc`, `flake.nix`, and
`flake.lock`. Cache renewal is expected after edits to those files, flake input
updates, deleting `.direnv`, missing profile rc files, or GC if the profile root
is gone.

## Kept changes

- Added `docs/runbooks/nix-direnv-cache-health.md` with cache health checks,
  timing command, expected healthy state, and invalidation causes.

## Commands run

- `br show dotfiles-d6fc`
- `git status --short`
- `sed -n '1,220p' config/direnv/direnvrc`
- `sed -n '1,160p' .envrc`
- `sed -n '1,120p' modules/shell/direnv.nix`
- `rg -n "direnv|nix-direnv|devShell|devshell|shellHook" flake.nix modules config -S`
- `cat .pi/skills/zbench/SKILL.md`
- `direnv status`
- `direnv allow .`
- `DIRENV_LOG_FORMAT='%s' /usr/bin/time -p direnv exec . true`
- `find .direnv -maxdepth 4 -ls`
- `nix-store --query --roots "$(readlink .direnv/flake-profile-*)"`
