# Zsh startup

`modules/shell/zsh/default.nix` links this directory to `$XDG_CONFIG_HOME/zsh`.
Preserve `.zshrc` startup order: Powerlevel10k instant prompt → essential XDG
defaults/helpers → `config.zsh` → Antidote/static bundle → `.p10k.zsh` →
interactive keybindings/completion/generated rc/local hooks.

`.zshenv` owns noninteractive environment and PATH ordering. Tool-specific
environment/PATH belongs in `config/<tool>/env.zsh`; aliases, completion, and
lazy interactive initialization belong in `config/<tool>/aliases.zsh`. The
module discovers them into `envFiles` / `rcFiles` and generated `extra.zshenv` /
`extra.zshrc`. Machine-local state belongs in untracked `local.zshrc`, not
installer edits or literal user home paths in managed sources.

Syntax check for startup changes. Invoke Zsh once per file; extra filenames are script arguments, not additional syntax checks.

```sh
for file in config/zsh/.zshrc config/zsh/.zshenv config/zsh/config.zsh \
  config/*/env.zsh config/*/aliases.zsh; do
  zsh -n "$file" || exit 1
done
```

For startup latency, use `hey zbench --iters 1` and the `zbench` skill.
Syntax checking does not cover ordering or latency; use an interactive shell for
startup behavior and benchmark only when the change can affect startup cost.
