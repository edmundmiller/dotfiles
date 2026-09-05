# Zsh integration

The module discovers `config/*/aliases.zsh` and `env.zsh`, excluding Claude
unless enabled. `rcFiles` are sourced before `rcInit`; the analogous env inputs
generate `extra.zshenv`. `.zshrc`/`.zshenv` must source these generated files.

`config/zsh/` is recursively linked, leaving room for unmanaged local files.
Tool-specific shell behavior belongs in its config source, not generated
`extra.zshrc` or `extra.zshenv`.
