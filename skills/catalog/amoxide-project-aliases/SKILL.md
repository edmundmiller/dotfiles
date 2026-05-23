---
name: amoxide-project-aliases
description: Use amoxide for project-local .aliases and optional profiles when commands are simple, trusted, and useful to agents without shadowing zsh aliases.
---

# Amoxide Project Aliases

Use this skill when a repo has repeated project commands that an agent should discover and run consistently, or when you are considering adding a project-local `.aliases` file.

## When Amoxide Helps Agents

Amoxide is useful for agents when it creates a small, trusted command vocabulary for a project:

- `check` for the canonical validation chain.
- `test`, `lint`, `fmt`, `build`, `dev` for project-specific implementations.
- `fix` for safe auto-fix commands.
- `agent-check` or `ci-local` for concise agent-friendly validation.

This is especially helpful when the underlying commands are long, vary by repo, or compose several tools.

## Do Not Mirror Global zsh Aliases

Do not mechanically copy aliases from `config/*/aliases.zsh` into Amoxide.

Global zsh aliases/functions remain authoritative for interactive shell behavior. They may include wrappers, lazy completions, conditionals, or richer functions that Amoxide TOML aliases cannot represent well.

Avoid short names that shadow established global aliases unless the project intentionally wants to override them. Risky examples include common Git/JJ names such as `gp`, `jd`, `js`, `ja`, and `gl`.

## Preferred `.aliases` Shape

Keep project aliases boring, discoverable, and command-oriented:

```toml
[aliases]
check = "fmt && lint && test"
fmt = "treefmt"
lint = "nix flake check"
test = "pytest"
build = "nix build"
```

Then run:

```bash
am trust
am ls
check
```

Project `.aliases` files are local/trusted per machine in this dotfiles setup and are ignored globally by Git. If a project wants shared aliases, discuss whether the file should be committed and documented for that repo.

## Parameterized Aliases

Normal Amoxide aliases append trailing arguments automatically, so no template is needed for simple cases:

```toml
[aliases]
test = "cargo test"
```

Use templates only when argument placement matters:

```toml
[aliases]
gri = "git rebase -i HEAD~{{1}}"
deploy = "rsync -avz {{@}} host:/srv/app/"
```

Use `{{@}}` for all arguments at a specific location, `{{1}}`, `{{2}}`, etc. for positional arguments, and `--raw` when creating aliases whose literal command contains `{{...}}` syntax.

## Composing Aliases

Composition is valuable for agents because it documents the canonical workflow:

```toml
[aliases]
fmt = "treefmt"
lint = "nix flake check"
test = "pytest"
check = "fmt && lint && test"
```

Only compose from aliases that will be active or loaded in the project. Avoid project aliases that depend on inactive optional profiles unless the dependency is documented.

## Agent Workflow

1. Check whether Amoxide is available:

   ```bash
   command -v am
   ```

2. If a project has `.aliases`, inspect it before trusting:

   ```bash
   cat .aliases
   am trust
   am ls
   ```

3. Prefer the project alias for canonical commands once trusted:

   ```bash
   check
   test
   build
   ```

4. If adding aliases, use clear command names first (`check`, `test`, `lint`) before terse personal shortcuts.

## When Not To Use

Do not add Amoxide aliases when:

- The command is used once and is obvious.
- The alias would hide a destructive command behind a cute short name.
- The alias conflicts with established zsh/git/jj shortcuts.
- A repo already has a clear task runner (`just`, `make`, `npm scripts`, `nix flake check`) and an alias would add another layer without simplifying agent usage.
