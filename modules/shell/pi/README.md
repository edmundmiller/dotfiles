# Pi Module

Pi coding agent configuration plus shell helpers for common local workflows.

## Shell Helpers

The zsh module auto-sources `config/pi/aliases.zsh`, which provides:

| Helper                    | Description                                                                                                                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `piw [name] [pi args...]` | Create a sibling git worktree, `cd` into it, and launch the real `pi`. Omitting `name` auto-generates one. Use `piw -- "prompt"` when you want an auto-generated name plus a prompt. |
| `pir <pr> [pi args...]`   | Show quick PR context with `gh pr view`, run `gh pr checkout`, then launch the real `pi` with a default review-oriented prompt.                                                      |

These helpers intentionally avoid shadowing the packaged `pi` binary.
