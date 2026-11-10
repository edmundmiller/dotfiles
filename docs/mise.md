---
purpose: Explain project-local tasks, environment setup, and the hey migration.
applies_to: Dotfiles development and other projects adopting the same pattern.
entrypoint: mise trust, then mise tasks.
verification: mise tasks validate and python3 -m unittest tests/test_mise_tasks.py.
update_when: Task discovery, shell integration, or migration behavior changes.
---

# Project-local commands with mise

Mise owns project environment variables and discovers executable file tasks in
`bin/hey.d/`. Thin Bash entrypoints carry `#MISE` metadata and call native Bend
controllers in `packages/hey/`; task execution does not require Nushell.
`mise.toml` sets `[task_config].includes = ["bin/hey.d"]`.
Mise skips dot-prefixed subdirectories. Mechanical helpers such as the Homebrew
process wait remain hidden in `.lib/`; typed task policy stays in Bend.
There is no global task catalog or second dispatcher.

Related tasks live in subdirectories. Mise turns the path into a colon-separated
name: `nuc/status` is `nuc:status`. A directory's `_default` keeps its short
entrypoint: `nuc/_default` is `nuc`. Common commands such as `check`, `dev`,
and `rebuild` stay at the root. For example:

```text
bin/hey.d/
  check
  dev
  rebuild
  ergodox/
    build
    flash
  nuc/
    _default
    status
    worktree
  skills/
    sync
    update
```

```sh
mise trust                    # after reviewing this checkout's config and tasks
mise tasks --extended         # names, aliases, and source paths
mise run check --plan
mise run re --help
mise run nuc:worktree --help
hey check --plan              # same task, compatibility spelling
mise run dev                  # enter the default Nix shell explicitly
mise run dev full             # include deployment tools
mise run dev default nu --version
```

The `hey` executable only forwards to mise. It works with any project's tasks,
not only dotfiles. With no arguments it lists tasks. Existing hyphenated names
remain aliases, so `hey nuc-status` and `mise run nuc:status` run the same file.
`re`, `u`, and `nuc-wt` also remain aliases. From outside dotfiles use
`mise --cd "$DOTFILES" run <task>`.
An inherited `FLAKE_DIR` no longer redirects a task into another checkout.
The dispatcher only forwards arguments. Native controllers are packaged
separately; checkout launchers build the current `#hey` package before executing
them. Source edits need no host activation, though compilation may run on first
use. Tasks preserve the caller's tool order on PATH after mise applies the
project environment. Privileged operations add their required paths only in the
selected child environment.

Tasks keep the existing guards, argument parsing, and terminal access for sudo,
SSH and interactive commands. A task name is not permission to run it. Rebuilds,
deployment, cleanup and publication still require authorization under
[the command policy](adr/0001-agent-command-policy.md).

# Replacing direnv

This repo's `mise.toml` replaces `.envrc`. Entering the directory sets the
Beads variable and adds `bin` to PATH. It does not evaluate the flake or install
Git hooks. Enter `mise run dev` when you need the Nix shell and
its hook setup. `dev` resolves GitHub credentials for the Nix child without
changing the caller's `NIX_CONFIG`.

Move `.envrc.local` values into an ignored `mise.local.toml` `[env]` table.
`DOTFILES_DIRENV_MODE` is retired; `dev` and `dev full` replace its shell modes.
No private local files are migrated automatically.

After an authorized host rebuild, open a new terminal. Hosts with mise enabled
no longer load the direnv hook, because running both environment hooks is
unsupported upstream. Other projects still using `.envrc` must be migrated
before relying on their automatic environments. Hosts without mise enabled
can still use the legacy direnv module.

For another project, put its environment in its own `mise.toml` and its commands
in its own `bin/hey.d/`, with `[task_config].includes = ["bin/hey.d"]`.
Use `[env]` values for exports, `_.file` for dotenv,
and `_.path` for PATH additions. Review shell code rather than blindly importing
`.envrc`; `use flake` is not a mise directive. Keep Nix development shells
explicit when their setup has side effects. See the
[upstream migration guide](https://mise.jdx.dev/direnv.html).

# Optional MCP access stays scoped to a checkout

No global mise MCP server is installed. In a client that supports local stdio
servers, configure the absolute result of `command -v mise` with arguments
`["--cd", "/absolute/path/to/checkout", "mcp"]`. For Claude Code, run this from
the intended checkout after reviewing and trusting it:

```sh
claude mcp add --scope local mise -- "$(command -v mise)" --cd "$PWD" mcp
```

Restart the server after editing tasks or configuration. Prefer `mise://tasks`
for discovery. `mise://env` may expose secrets from local overrides, and
`run_task` can activate hosts or publish changes. Require client approval for
mutating tasks; do not blanket-approve the server. An MCP connection grants no
deployment authority. See [mise MCP documentation](https://mise.jdx.dev/mcp.html).
