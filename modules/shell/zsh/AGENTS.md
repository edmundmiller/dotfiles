# Zsh Module - Agent Guide

## Purpose

System zsh setup + shared rc/env injection for other modules.

## Module Structure

```
modules/shell/zsh/
├── default.nix
└── AGENTS.md

config/zsh/
├── .zshrc
├── .zshenv
├── prompt.zsh
└── ...
```

## Key Facts

- `enable` adds `pkgs.zsh` to `environment.shells` + `programs.zsh`.
- Auto-sources `config/*/aliases.zsh` + `config/*/env.zsh` (skips `claude` unless enabled).
- Writes `~/.config/zsh/extra.zshrc` + `extra.zshenv` from `rcFiles/envFiles` + `rcInit/envInit`.
- Symlinks `config/zsh/` into `~/.config/zsh` recursively.
- Sets `ZDOTDIR`, `ZSH_CACHE`, and shell aliases.

## Options

```nix
modules.shell.zsh = {
  enable = true;
  rcInit = "";   # appended to extra.zshrc
  envInit = "";  # appended to extra.zshenv
  rcFiles = [ ... ];
  envFiles = [ ... ];
};
```

## Gotchas

- `.zshrc`/`.zshenv` must source `extra.zshrc`/`extra.zshenv`.
- Add tool aliases via `config/<tool>/aliases.zsh` or `modules.shell.zsh.rcFiles`.

## Related

- `modules/shell/tmux/` (rcFiles usage)
- `config/zsh/*`
