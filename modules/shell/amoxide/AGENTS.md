# Amoxide integration

`config/*/aliases.zsh` owns global interactive aliases and functions. Amoxide
initializes later through `rcInit` and can shadow their richer behavior,
especially `gp`, `jd`, `js`, `ja`, and `gl`. Do not mirror zsh aliases into it.

Use Amoxide for trusted project `.aliases`, optional profiles, and simple
portable commands; the `amoxide-project-aliases` skill covers syntax. Precedence
is project → active profiles (last wins) → global config.

`config/amoxide/` owns config/profile/session templates. `security.toml` contains
machine-local trust decisions and remains Amoxide-managed, not declarative.
