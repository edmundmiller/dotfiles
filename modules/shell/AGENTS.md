# Shell modules

System-wide aliases belong in the owning module's `environment.shellAliases`.
Interactive tool aliases/functions belong in `config/<tool>/aliases.zsh`;
the zsh module discovers them or accepts explicit `rcFiles`.

`extra.zshrc` and `extra.zshenv` are generated from `rcFiles`/`rcInit` and
`envFiles`/`envInit`. Recursive linking of `config/zsh` permits an unmanaged
`~/.config/zsh/local.zshrc` for host-local customization.
