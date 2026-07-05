---
name: skillopt-sleep-omp
description: Use when the user wants OMP to run Microsoft SkillOpt-Sleep, learn from past OMP sessions, review or adopt staged skill improvements, or schedule an offline sleep/dream self-improvement cycle.
---

# SkillOpt-Sleep for OMP

This is the OMP thin shell for Microsoft SkillOpt-Sleep. It follows the upstream
Claude Code, Codex, Devin, and OpenClaw pattern: harvest local agent sessions,
mine recurring tasks, replay them offline, gate proposed memory/skill edits on a
held-out score, and stage improvements for review before adoption.

## When to use

Use this when the user asks OMP to:

- learn from prior OMP sessions or repeated feedback;
- run a nightly/offline sleep, dream, or self-improvement cycle;
- inspect SkillOpt-Sleep status, harvest, dry-run, run, adopt, schedule, or unschedule;
- refine reusable Agent Skills from real OMP usage with validation gates.

## Mechanism

The upstream `skillopt_sleep` engine currently knows Claude Code and Codex
transcript sources. The bundled wrapper mirrors OMP JSONL sessions into a
Claude-compatible, sanitized mirror at `~/.skillopt-sleep/omp/claude-home`, then
runs `python -m skillopt_sleep` with `--source claude --claude-home <mirror>`.

- Source sessions: `~/.omp/agent/sessions/**/*.jsonl`
- Mirror state: `~/.skillopt-sleep/omp/claude-home`
- SkillOpt state/staging: managed by SkillOpt-Sleep, normally under
  `~/.skillopt-sleep/`
- Live changes: none until `adopt`; every adoption is backed up by the engine

Tool outputs are not mirrored. The wrapper keeps user/assistant text and
assistant tool names, enough for SkillOpt to mine recurring task patterns without
copying raw tool results.

## Commands

Set `SKILLOPT_SLEEP_REPO` when SkillOpt is cloned somewhere the wrapper cannot
auto-detect:

```bash
export SKILLOPT_SLEEP_REPO=/path/to/SkillOpt
```

Run from the project whose memory/skills should evolve:

```bash
# Safe smoke check, no proposal staged
python skills/catalog/skillopt-sleep-omp/scripts/skillopt-sleep-omp.py dry-run \
  --backend mock --max-sessions 5 --max-tasks 3 --progress

# Full cycle; stages a proposal only
python skills/catalog/skillopt-sleep-omp/scripts/skillopt-sleep-omp.py run \
  --backend codex --max-sessions 10 --max-tasks 5 --progress

# Inspect staged proposals and history
python skills/catalog/skillopt-sleep-omp/scripts/skillopt-sleep-omp.py status

# Adopt only after explicit review/approval
python skills/catalog/skillopt-sleep-omp/scripts/skillopt-sleep-omp.py adopt

# Nightly wrapper schedule; this installs cron for the OMP wrapper, not the
# upstream bare `python -m skillopt_sleep run`.
python skills/catalog/skillopt-sleep-omp/scripts/skillopt-sleep-omp.py schedule \
  --hour 3 --minute 17 --backend codex --max-sessions 10 --max-tasks 5

python skills/catalog/skillopt-sleep-omp/scripts/skillopt-sleep-omp.py unschedule
```

Actions are `status`, `harvest`, `dry-run`, `run`, `adopt`, `schedule`, and
`unschedule`. `schedule` / `unschedule` are handled by this OMP wrapper so the
nightly job refreshes the OMP transcript mirror before invoking SkillOpt-Sleep.
Other actions pass through to upstream `python -m skillopt_sleep` with
`--source claude` and the mirrored OMP home injected by default. Upstream flags
such as `--target-skill-path`, `--tasks-file`, `--backend`, `--model`,
`--edit-budget`, `--lookback-hours`, `--max-sessions`, `--max-tasks`,
`--progress`, and `--json` pass through unchanged.

Wrapper-only flags:

| Flag                    | Meaning                                                                                      |
| ----------------------- | -------------------------------------------------------------------------------------------- |
| `--omp-sessions DIR`    | Override the OMP session root. Defaults to `~/.omp/agent/sessions`.                          |
| `--omp-mirror-home DIR` | Override the Claude-compatible mirror home. Defaults to `~/.skillopt-sleep/omp/claude-home`. |
| `--help-omp-wrapper`    | Show wrapper-specific help.                                                                  |
| `--self-test`           | Validate the OMP-to-Claude transcript translator without SkillOpt.                           |

## Recommended workflow

1. Start with `dry-run --backend mock --json` to validate harvesting and task
   mining without API spend.
2. For real improvement, use `run --backend codex` or another upstream-supported
   backend. Keep `--max-sessions`, `--max-tasks`, and budget flags bounded.
3. Read the staged `report.md` and proposed edits before summarizing.
4. Adopt only after explicit user approval. Do not hand-edit memory or skills as
   a substitute for `adopt`.

## Safety rules

- OMP session harvest is read-only; never edit `~/.omp/agent/sessions`.
- Keep raw secrets, private transcript contents, and raw tool outputs out of
  chat, logs, commits, and generated skill text.
- Treat generated edits as proposals until the held-out gate and human review
  approve them.
- Prefer the `mock` backend for plumbing checks; real backends spend the user's
  own agent budget.
- If using `--tasks-file` with a real backend, review and mark the task file as
  reviewed according to upstream SkillOpt-Sleep rules.
