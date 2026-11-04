# Shell modules

System-wide aliases belong in the owning module's `environment.shellAliases`.
Interactive tool aliases/functions belong in `config/<tool>/aliases.zsh`;
the zsh module discovers them or accepts explicit `rcFiles`.

`extra.zshrc` and `extra.zshenv` are generated from `rcFiles`/`rcInit` and
`envFiles`/`envInit`. Recursive linking of `config/zsh` permits an unmanaged
`~/.config/zsh/local.zshrc` for host-local customization.

Run `hey check modules/shell config/<tool>` for module and source changes. Add
the tool's scoped syntax or behavior check; generated shell fragments are outputs
of the module and must not be edited in the live profile.
