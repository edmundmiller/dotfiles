# Pi Module

Pi coding agent configuration plus shell helpers for common local workflows.

## Shell Helpers

The zsh module auto-sources `config/pi/aliases.zsh`, which provides:

| Helper                    | Description                                                                                                                                                                                                               |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `piw [name] [pi args...]` | Create a git worktree under `.pi/worktrees/`, `cd` into it, and launch the real `pi`. Omitting `name` auto-generates one. Use `piw -- "prompt"` when you want an auto-generated name plus a prompt.                       |
| `pir [pr] [pi args...]`   | Without a PR number, review the current checkout against `origin/main`. With a PR number, show quick PR context with `gh pr view`, run `gh pr checkout`, then launch the real `pi` with a default review-oriented prompt. |

These helpers intentionally avoid shadowing the packaged `pi` binary.
