# Pi Module

Pi coding agent configuration plus shell helpers for common local workflows.

## Default behavior

`config/pi/settings.jsonc` keeps model/UI preferences and integrations while
leaving compaction, retries, message delivery, images, and skills at Pi defaults.
The shared core remains the only global instruction file.

Default packages exclude automatic goal/loop continuation, model switching,
response coaching, Agentmap/QMD prompt injection, and DCP/RTK/read rewriting.
Permissions, command policy, signing protection, Hermes memory, host integrations,
and explicit review/handoff commands remain available. `contextMemory.enable`
defaults to false; it opts into the additional `pi-context` package, not Hermes.

This is not a hook-free setup. `pi-markdown-workflows` retains nested AGENTS.md
discovery and also injects automatic workflow-selection guidance in projects
with `.pi/workflows`. Browser activation, memory, and permission hooks remain.
The image helper preserves attachments without modifying the system prompt.
`/goalize` is an explicit task-framing prompt, not a persistent goal service.

Use `modules.agents.pi.extraPackages` for deliberately opted-in packages rather
than growing the shared defaults. Local package sources remain available for
that purpose. Existing sessions retain their earlier context; test in a fresh
session after an authorized `hey re` applies the managed settings and links.

## Shell Helpers

The zsh module auto-sources `config/pi/aliases.zsh`, which provides:

| Helper                    | Description                                                                                                                                                                                                               |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `piw [name] [pi args...]` | Create a git worktree under `.pi/worktrees/`, `cd` into it, and launch the real `pi`. Omitting `name` auto-generates one. Use `piw -- "prompt"` when you want an auto-generated name plus a prompt.                       |
| `pir [pr] [pi args...]`   | Without a PR number, review the current checkout against `origin/main`. With a PR number, show quick PR context with `gh pr view`, run `gh pr checkout`, then launch the real `pi` with a default review-oriented prompt. |

These helpers intentionally avoid shadowing the packaged `pi` binary.
