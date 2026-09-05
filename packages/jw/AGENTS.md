# jw

Bash jj workspace manager. Each workspace has an isolated `@` in the same
repository; paths are computed from `JW_WORKSPACE_PATH` (default
`../{repo}--{name}`). Cross-workspace status uses `--repository`.

Interactive prompts/output use gum; `--json` stays unstyled. Counters use
`$((var + 1))`, not `((var++))`, whose initial zero value yields failure under `set -e`.
Exercise workspace creation/removal in a disposable repository, not live work.
