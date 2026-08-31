# hey.d guidance

- `hey` subcommands are Nushell modules; keep syntax compatible with the `nu` version provided by the repo dev shell.
- After editing `bin/hey.d/*.nu`, syntax-check with:

  ```bash
  nix develop --command nu --commands 'source bin/hey.d/common.nu; print ok'
  ```

  For files that only define subcommands and import `common.nu`, also source the edited file directly when practical, e.g.:

  ```bash
  nix develop --command nu --commands 'source bin/hey.d/rebuild.nu; print ok'
  ```

- Prefer agent-friendly output for long Nix commands when `AGENT=1` is set: concise progress, useful errors, and `--show-trace` on failures.
- Completion hooks run the current checkout's `bin/hey check --worktree`, not
  an installed generation, so a stop hook validates the same source it is closing.
- Darwin `hey check` resolves the existing `gh` credential into `NIX_CONFIG`
  only around Nix child commands. Never print the token or expose that augmented
  environment to Prek hooks.
