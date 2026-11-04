---
purpose: Explain the Claude CLI module and its managed files.
applies_to: Enabling or maintaining Claude Code in this dotfiles repo.
entrypoint: Set modules.agents.claude.enable and rebuild.
verification: Confirm the managed Claude files after rebuilding.
update_when: Claude module behavior or managed paths change.
---

# Claude CLI Module

Minimal nix-darwin wiring for Claude Code. This mainly exists so native Claude Code and `acpx claude` can share the same baseline Claude runtime config.

## Enable

```nix
modules.agents.claude.enable = true;
```

## What it manages

- `claude-code` package
- `~/.claude/settings.json` from `config/claude/settings.json`
- `~/.claude/CLAUDE.md` from the bounded `config/agents/core.md`
- `~/.claude/agents/` from `config/agents/modes/`
- `~/.claude/skills/{test-quality,github-cli-media,lore,pe-verify}` linked to shared catalog copies

## Plugin policy

The template enables `pstack@cursor-plugins` and points `cursor-plugins` at the
Nix-pinned marketplace. The settings bootstrap keeps other plugin and marketplace
entries already in `~/.claude/settings.json`. Template keys win. Retired DuckDB,
Plannotator, and WakaTime entries are removed on each bootstrap. This module
does not install any marketplace other than that pstack link.

## Notes

- Shared skills live in `~/.agents/skills`; Claude receives only the
  `test-quality`, `github-cli-media`, `lore`, and `pe-verify` links while
  activation removes other Claude skill copies
- Project-local skills belong in `.agents/skills/`
- If Claude reports settings schema errors, check `config/claude/settings.json`

## Session budget warnings

`~/.claude/hooks/session-budget` runs on `SessionStart`, `UserPromptSubmit`, and
`Stop`. It warns, and never blocks, when:

- the session's context passes `CLAUDE_CONTEXT_WARN_TOKENS` (default 250000), and
  again on each `CLAUDE_CONTEXT_WARN_STEP_TOKENS` (default 100000) beyond it
- the session's generation count passes `CLAUDE_GEN_WARN_SOFT` (default 250),
  then again at `CLAUDE_GEN_WARN_HARD` (default 300)
- a session first seen on an earlier America/Chicago day is resumed

A generation is one main-thread assistant message with a `usage` object.
Content blocks sharing a `message.id` count once, including across appended
reads. Rows without an ID count individually. Subagent entries with
`isSidechain` set and assistant entries without `usage` do not count.
The per-session state file stores the seen message IDs, a byte offset and a
hash of the first 256 bytes. Later checks read only the lines appended after
that offset. If the file no longer reaches the offset, or those first bytes
changed, the hook counts it again from the beginning.

Context size still comes from the newest main-thread assistant `usage` in the
tail of the transcript, counting input, cache-read, and cache-creation tokens.
Generation warnings run on `UserPromptSubmit` and `Stop`, with the context
check, so both can be returned on one event. `SessionStart` still reports a
stale resume, and context size when the transcript is over that threshold.
Each generation threshold warns once per session. Set `CLAUDE_GEN_WARN_SOFT=0` or
`CLAUDE_GEN_WARN_HARD=0` to silence that warning. Set
`CLAUDE_CONTEXT_WARN_TOKENS=0` to silence the context warning.

Warnings are recorded per session under `$XDG_CACHE_HOME/claude-session-budget`.

Activation adds the hook to `~/.claude/settings.json` alongside hooks the runtime
registered, keyed on its command, so Herdr, Entire, and plugin hooks stay intact.
