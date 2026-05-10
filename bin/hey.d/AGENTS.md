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
