# modules/shell/git

Git tooling module. Symlinks configs from `config/git/`, `config/gh/`, `config/lazygit/`.

## Options

- `modules.shell.git.enable` — core git packages + config symlinks
- `modules.shell.git.ai.enable` — git-ai authorship tracking; injects `pi-git-ai` into `modules.agents.pi.extraPackages` when pi is also enabled
- `modules.shell.git.stack.enable` — install Kit Langton's squash-safe stacked PR `stack` CLI (defaults on with git)
- `modules.shell.git.lazydiff.enable` — install LazyDiff terminal diff/PR reviewer (defaults on with git)

## Packages

git-open, difftastic, sem, lazydiff, diffity, delta, git-crypt (if gnupg enabled), git-lfs, pre-commit, git-hunks, ghui (Darwin Homebrew: `kitlangton/tap/ghui`)

## Config files symlinked

- `config/git/{config,config-seqera,config-nfcore,ignore,allowed_signers}` → `~/.config/git/`
- `config/gh/{config.yml,hosts.yml}` → `~/.config/gh/`
- `config/gh-dash/config.yml` → `~/.config/gh-dash/`
- `config/lazygit/config.yml` → `~/.config/lazygit/` (force-overwrite)
- `config/git/aliases.zsh` → zsh rcFiles

## Cross-module deps

- `modules.shell.gnupg` — conditionally adds git-crypt
- `modules.agents.pi` — `ai.enable` pushes pi-git-ai package via `extraPackages`
