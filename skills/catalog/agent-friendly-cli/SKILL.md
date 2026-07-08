---
name: agent-friendly-cli
description: Design and implement CLIs that work well for both humans and AI coding agents, with progressive disclosure, structured output, actionable errors, stdout/stderr separation, and explicit non-interactive modes.
---

# Agent-Friendly CLI Design

Use this skill when building, reviewing, or redesigning a command-line tool meant to be used by both humans and coding agents. Do not use it merely to decide whether to prefix an arbitrary command with environment variables.

## Design principles

Model the CLI after Notion's `ntn`: one tool that is pleasant for humans, scriptable for shells, and predictable for agents.

1. **Progressive disclosure** — make the common path short, with deeper help/docs/spec output behind flags or subcommands.
2. **Actionable errors** — say what failed, why it likely failed, and the exact next command or flag to try.
3. **Separate data from messages** — write machine-readable data to stdout; write progress, warnings, prompts, and diagnostics to stderr.
4. **Interactive and non-interactive modes** — prompts are fine for humans, but every prompt must have a flag/env/stdin equivalent for agents and CI.

## Output contract

- Provide `--json` for structured output on list/get/status commands.
- Provide plain stable output when JSON is too heavy, e.g. TSV with `--plain`.
- Keep stdout parseable: no spinners, colors, banners, or prose in data mode.
- Put progress and diagnostics on stderr.
- Redact secrets in logs by default; make unsafe verbose modes explicit and scary.

## Command shape

- Prefer predictable nouns and verbs: `tool workers list`, `tool pages get <id>`.
- Support `--help` at every level.
- Add `doctor` for auth/config/network checks.
- Add `--verbose` for source chains and request/response metadata.
- Add `--yes` for destructive confirmations in non-interactive runs.
- Add `--no-watch`, `--no-browser`, `--no-install`, or equivalent escape hatches for commands that would otherwise block.

## Input contract

- Accept stdin for large JSON/Markdown payloads.
- Accept `--data` or `--file` for scriptable payloads.
- Accept env vars for CI/auth overrides, but keep flags higher clarity for one-off commands.
- Avoid requiring TTY-only flows for setup; provide a polling, token, or copied-code path.

## Agent affordances

- Document examples agents can paste directly.
- Provide live reference commands where possible: `api ls`, `--spec`, `--docs`, `--json`.
- Make errors self-recovering: include missing config paths, required flags, and safe retry commands.
- Keep command output deterministic unless watch/stream mode is explicitly requested.

## Checklist

- [ ] Common human path is one short command.
- [ ] Every interactive prompt has a non-interactive equivalent.
- [ ] Data mode writes only data to stdout.
- [ ] Logs/progress/errors go to stderr.
- [ ] `--json` exists for agent parsing.
- [ ] Errors include the next concrete fix.
- [ ] Secrets are redacted by default.
