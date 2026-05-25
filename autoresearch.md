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

# Devshell split autoresearch — dotfiles-gaq3

## Goal

Investigate whether dotfiles direnv startup improves if the default devshell is lightweight and heavy development tooling moves to `.#full`.

## Baseline measurements

Repo/worktree: `/Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-gaq3-devshell`.
Branch: `worktree/gaq3-devshell`.

Initial `git status --short` was clean.

Baseline default shell contents:

- direct packages: `nixfmt`, `deadnix`, `statix`, `deploy`, `nushell`, `br`
- plus `config.pre-commit.settings.enabledPackages`
- shell hook ran `config.pre-commit.shellHook`, which installs/updates git hooks

Warm/cache-ish timings before changes:

| command | run 1 | run 2 | run 3 |
| --- | ---: | ---: | ---: |
| `direnv export json` with valid existing cache | 0.01s | 0.01s | 0.00s |
| `nix develop --command true` | 8.34s | 1.47s | 0.89s |

Notes:

- `nix develop` run 1 printed `git-hooks.nix: updating ... repo`, so hook installation dominated that run.
- A later apples-to-apples cached baseline after restoring the original flake measured `nix develop --command true` at 0.70s, 0.85s, 1.09s.

## Prototype kept

Changed `devShells.default` to a lightweight `pkgs.mkShellNoCC` with:

- `self.packages.${system}.agent-env.paths` for routine agent/shell work (`git`, `jj`, `gh`, `br`, `direnv`, `just`, search tools, etc.)
- Nix edit basics: `deadnix`, `nixfmt`, `nushell`, `statix`
- no `config.pre-commit.shellHook`
- no deploy package

Added `devShells.full` preserving the previous default shell behavior:

```bash
nix develop .#full
```

Use full shell when hook installation or deploy tooling is needed.

## Prototype measurements

After split, with dirty-tree warning present due to the prototype itself:

| command | run 1 | run 2 | run 3 |
| --- | ---: | ---: | ---: |
| `nix develop --command true` default | 0.70s | 0.61s | 0.55s |
| `nix develop .#full --command true` | 0.72s | 0.60s | 0.66s |
| `direnv export json` after cache invalidation | 13.35s | 0.14s | 0.14s |

A separate `mkShellNoCC` rebuild run measured default at 8.90s, 1.17s, 0.64s; first run included building the changed shell derivation. Cached performance matters more for normal direnv use.

## Validation

- `nix develop --command bash -lc 'for c in br git gh jj direnv nixfmt deadnix statix nu just; do command -v "$c"; done'` — all present in default shell.
- `nix develop .#full --command bash -lc 'command -v pre-commit; command -v deploy'` — full shell has hook tooling and deploy-rs binary (`deploy`).
- `nix flake check --no-build` evaluated devshells but failed later at existing cross-platform skills-catalog issue: `Cannot build ... dotfiles-skills-catalog.drv. Required system: x86_64-linux Current system: aarch64-darwin`.

## Tradeoffs

Pros:

- Default direnv no longer installs/updates pre-commit hooks.
- Routine agent commands remain available.
- Full previous workflow preserved at `nix develop .#full`.

Cons:

- Hook installation no longer happens automatically on every direnv load. Developers must enter `.#full` when they need hooks refreshed.
- Initial cache invalidation still costs several seconds; split mostly helps when hook installation or heavy shell closure changes are the bottleneck.
- Cached `direnv export json` was already very fast with nix-direnv; improvement in steady-state direnv is small.

## Recommendation

Keep the split. It is low-risk, preserves normal agent commands, and moves hook/deploy behavior to an explicit full shell. Expected benefit is avoiding surprising hook work during routine direnv loads, not eliminating Nix evaluation cost.


---

# Zsh startup autoresearch

## Baseline

The installed `hey zbench --iters 4` failed before running zsh-bench because Nushell treated `--iters` as a flag for the `hey zbench` custom command. For exploratory shell-performance runs I used direct `zsh-bench --iters 4` until fixing the repo-local harness.

Direct baseline (`zsh-bench --iters 4`):

| metric               |      ms |
| -------------------- | ------: |
| first_prompt_lag_ms  |  27.894 |
| first_command_lag_ms | 689.543 |
| command_lag_ms       | 175.074 |
| input_lag_ms         |   4.986 |
| exit_time_ms         | 334.448 |

Repo-local harness after fix (`./bin/hey zbench --iters 4`, confirmation run):

| metric               |    ms |
| -------------------- | ----: |
| first_prompt_lag_ms  |  28.6 |
| first_command_lag_ms | 681.0 |
| command_lag_ms       | 168.5 |
| input_lag_ms         |   5.2 |
| exit_time_ms         | 325.7 |

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

# dotfiles-r7yx: conditional dotfiles direnv loading

## Question

Can routine dotfiles worktrees get cheap variables without always paying `use flake`, while keeping full Nix dev tools easy and preserving current behavior by default?

## Current behavior

`.envrc` exported:

- `WORKTRUNK_WORKTREE_PATH="../{{ repo }}.{{ branch | sanitize }}"`
- `BEADS_NO_DAEMON=1`
- unconditional `use flake`

`config/direnv/direnvrc` only sources nix-direnv and defines helper functions. `use flake` is supplied by nix-direnv/Home Manager.

The default dev shell in `flake.nix` installs `nixfmt`, `deadnix`, `statix`, deploy-rs, Nu, beads-rust, and pre-commit hook packages. Its shellHook installs/updates pre-commit hooks and prints `dotfiles development shell`. The `agent` shell is separate and explicit (`nix develop .#agent`).

`pi-direnv` runs `direnv export json` on session start, then applies the resulting variables to Pi's process environment. So any expensive `use flake` in `.envrc` is also paid by Pi/agent startup when direnv reloads.

## Measurements

Worktree: `/Users/emiller/.local/share/herdr/worktrees/dotfiles/worktree-r7yx-envrc`.

Current unconditional `use flake`:

| case                                  | `direnv export json` wall time |
| ------------------------------------- | -----------------------------: |
| cached, before touching `.envrc`      |                     0.00-0.01s |
| forced reload after touching `.envrc` |                         19.81s |

After adding conditional mode:

| mode                       | behavior                                    | `direnv export json` wall time |
| -------------------------- | ------------------------------------------- | -----------------------------: |
| default/full, first reload | runs `use flake`, pre-commit hook shellHook |                         18.01s |
| default/full, cached       | runs cached dev shell                       |                          0.27s |
| light via `.envrc.local`   | exports only cheap variables + mode         |                          0.07s |
| light repeated             | same                                        |                          0.07s |

Validated light JSON contained `WORKTRUNK_WORKTREE_PATH` and `BEADS_NO_DAEMON`, and did not contain `IN_NIX_SHELL`. Full JSON contained `IN_NIX_SHELL=impure` plus dev-shell variables.

## Implemented design

`.envrc` now defaults to full mode, preserving current automatic Nix dev environment:

```sh
case "${DOTFILES_DIRENV_MODE:-full}" in
  full) use flake ;;
  light) ;;
  *) warn and fall back to use flake ;;
esac
```

It also:

- `watch_file .envrc.local`
- `source_env_if_exists .envrc.local`
- ignores `.envrc.local` in `.gitignore`

Use:

```sh
printf 'export DOTFILES_DIRENV_MODE=light\n' > .envrc.local
direnv allow .
```

To return to full mode:

```sh
rm .envrc.local
direnv allow .
```

## Rejected options

1. Make light mode the default.
   - Rejected: violates guardrail; users expecting automatic Nix dev tools would silently lose them.
2. Automatically choose light mode in Herdr/Pi worktrees.
   - Rejected: hidden context-dependent behavior would make shells inconsistent and harder to debug.
3. Require a global environment variable only.
   - Rejected: useful for automation, but less discoverable/persistent per worktree than `.envrc.local`.
4. Split `.envrc` into multiple tracked variants.
   - Rejected: more files and switching friction with no benefit over an ignored local override.

## Recommendation

Keep full mode as default. For routine agent/research worktrees, opt into light mode with ignored `.envrc.local`. This avoids the ~18-20s uncached flake reload path while preserving Pi/beads/worktree variables and avoiding surprise behavior changes for normal interactive development.
