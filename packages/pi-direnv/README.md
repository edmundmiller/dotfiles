# pi-direnv

Auto-load [direnv](https://direnv.net/) environment at session start. Ensures bash commands have project-specific env vars from `.envrc` files.

## Install

```bash
pi install npm:pi-direnv
```

## What it does

On `session_start`:

1. Checks if `direnv` is installed (skips silently if not)
2. Searches for `.envrc` from cwd up to the git root
3. Runs `direnv export json` and applies variables to `process.env`
4. Shows a notification with the count of loaded vars
5. Warns if `.envrc` is blocked (needs `direnv allow`)

## Why

Nix flakes + direnv is a common pattern. Without this extension, `pi exec` commands miss project-specific PATH entries, env vars, and tool versions defined in your flake's `devShell`.

Inspired by [simonwjackson/opencode-direnv](https://github.com/simonwjackson/opencode-direnv).
