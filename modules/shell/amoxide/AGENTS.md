# Amoxide Shell Integration

## Alias Ownership

`config/*/aliases.zsh` remains the source of truth for global interactive zsh aliases and functions.
Do **not** mechanically import or mirror those files into Amoxide profiles.

Reasons:

- zsh alias files can define functions, wrappers, conditionals, completions, and shell-state-aware behavior (`git()`, `jj()`, `gcl`, `jl`, etc.).
- Amoxide aliases are TOML command strings rendered into the current shell; they are best for simple commands, profile/project scoping, and portability.
- The zsh module sources `rcFiles` before `modules.shell.zsh.rcInit`, and Amoxide is initialized from `rcInit`; if an Amoxide alias has the same name as a zsh alias/function, Amoxide can shadow the zsh behavior.

Avoid overlapping short names with existing zsh aliases unless the Amoxide alias intentionally matches the zsh behavior and the loss of any function wrapper is acceptable.

Known risky overlaps include Git/JJ names such as `gp`, `jd`, `js`, `ja`, and `gl`, where the zsh definitions have established meanings or richer behavior.

## What Belongs in Amoxide

Prefer Amoxide for:

- Project-local `.aliases` files that are reviewed and trusted per project/machine.
- Optional profiles for ecosystems that are not always active (`rust`, `node`, etc.).
- Simple portable aliases that should work outside zsh.
- Parameterized aliases where arguments need to be inserted somewhere other than the end, using `{{1}}`, `{{2}}`, or `{{@}}`.
- Composed aliases that build small project/profile commands from other Amoxide aliases.

Keep global Amoxide aliases sparse. If an alias is an everyday interactive zsh shortcut, put it in `config/<tool>/aliases.zsh` instead.

## Config File Model

Managed files live in `config/amoxide/` and are linked by `modules/shell/amoxide.nix`:

- `config.toml` — global aliases/options; keep sparse.
- `profiles.toml` — profile definitions.
- `session.toml` — active profiles; keep conflict-prone profiles inactive by default.
- `security.toml` — Amoxide-managed trust decisions; do not manage this in dotfiles unless there is a strong reason.
- `.aliases` — project-local aliases; ignored globally because they are local/trusted per machine.

Precedence from highest to lowest:

1. Project `.aliases`
2. Active profiles, with the last active profile winning conflicts
3. Global `config.toml` aliases

## Advanced Alias Guidance

- Normal aliases append trailing arguments automatically; no template is needed for commands like `cargo test`.
- Use parameterized aliases only when argument placement matters, for example `deploy = "rsync -avz {{@}} host:/srv/app/"` or `gri = "git rebase -i HEAD~{{1}}"`.
- Use `--raw` when creating an alias whose literal command contains `{{...}}` syntax.
- Composition is useful inside project aliases, e.g. profile alias `cl = "cargo clippy ..."` plus project alias `check = "cl && ct"`.
- Composition depends on both aliases being active/loaded; avoid composing project aliases from inactive profiles.
