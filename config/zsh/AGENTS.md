# Zsh Config

This directory holds the interactive zsh runtime that is symlinked to
`$XDG_CONFIG_HOME/zsh` by `modules/shell/zsh/default.nix`.

## Startup Shape

Keep `.zshrc` as the interactive shell lifecycle orchestrator, not a dumping
ground for tool setup. Its job is to preserve startup order:

1. Powerlevel10k instant prompt
2. Essential XDG/zsh defaults and helper functions
3. `config.zsh`
4. Antidote/static plugin bundle
5. `.p10k.zsh`
6. Interactive-only keybinds/completion/generated rc/local rc hooks

`.zshenv` owns non-interactive environment setup and canonical PATH ordering.
Avoid adding PATH mutations to `.zshrc`; put persistent PATH entries in
`.zshenv` or Nix `env` wiring instead.

## RC Seams Pattern

Tool-specific zsh behavior should live behind the module-provided rc/env seams:

- `config/<tool>/env.zsh` for environment variables and PATH additions needed
  before interactive shell startup. These are auto-discovered into
  `modules.shell.zsh.envFiles` and rendered into generated `extra.zshenv`.
- `config/<tool>/aliases.zsh` for aliases, functions, completions, and lazy
  interactive initialization. These are auto-discovered into
  `modules.shell.zsh.rcFiles` and rendered into generated `extra.zshrc`.

Examples:

- `config/bun/env.zsh` sets `BUN_INSTALL`; `config/bun/aliases.zsh` lazy-loads
  Bun completions.
- `config/sdkman/env.zsh` sets `SDKMAN_DIR`; `config/sdkman/aliases.zsh`
  lazy-loads SDKMAN command shims.
- `config/todo/aliases.zsh` owns the `t`/`ta`/`td`/`ttoday` aliases.

Use this pattern when adding or moving tool-specific shell code. Do not put new
Bun, SDKMAN, todo, Obsidian, agent, or installer-specific setup directly in
`.zshrc`.

## Local and Host-Specific State

Do not commit one-off installer edits or hard-coded user home paths such as
`/Users/emiller` or `/Users/edmundmiller` in managed startup files. Use `$HOME`,
Nix modules, tool-specific rc/env files, or untracked `local.zshrc` for local
machine state.

## Validation

After editing zsh startup files, run at least:

```sh
zsh -n config/zsh/.zshrc config/zsh/.zshenv config/zsh/config.zsh \
  config/*/env.zsh config/*/aliases.zsh
```

For startup-sensitive changes, also run the repo zsh benchmark/smoke harness,
for example:

```sh
nix develop --command nu --commands 'source bin/hey.d/common.nu; source bin/hey.d/zbench.nu; print ok'
./bin/hey zbench --iters 1
```
