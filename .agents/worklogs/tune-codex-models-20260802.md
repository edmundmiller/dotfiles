# Worklog: tune-codex-models-20260802

Status: complete

## Objective

Configure Codex around the native GPT-5.6 model roles: Sol High for primary work, Terra Medium for communicative subagents, Max selectable for exceptional tasks, and bounded multi-agent concurrency. Keep Luna available for clear standalone work without forcing it into subagent capabilities. Reclassify only scheduled tasks whose current model is a poor fit. Stop when source, live config, and updated automations agree and fresh checks pass.

## Decisions

- Do not install `sol-advisor`; its Luna subagent lane conflicts with the native collaboration capability boundary highlighted by the user.
- Keep Luna for narrow standalone scheduled work, where inter-agent communication is irrelevant.
- Use eight as the concurrency ceiling. It matches the current official multi-agent examples and avoids making twelve-way delegation the default.
- Keep Max opt-in instead of making it the default reasoning effort.

## Evidence

- Linked post metadata and attached media inspected on 2026-08-02.
- Fresh Codex manual fetched to `/var/folders/v4/yf1dl41n76j4fllz38zpzz_r0000gp/T/openai-docs-cache/codex-manual.md`.
- `codex-cli 0.145.0`; `multi_agent` stable/enabled; `multi_agent_v2` stable/disabled before this change.
- Source default was Sol XHigh; live default was Sol High; both exposed only Medium and Extra High in the reasoning picker.
- No custom model catalog, custom subagent files, or `sol-advisor` install found.
- Seven active scheduled tasks inspected through the Codex app and local automation metadata.
- Pre-change config assertion failed because source used Sol XHigh, omitted Max, and had no native subagent defaults.
- `python3 -m unittest tests.test_codex_model_config` passes three model-role and connector specs.
- `bash modules/agents/codex/test-seqera-mcp.sh` passes.
- `hey check` passed child lock sync, Darwin evaluation, formatting, hooks, tmux, package harness, package policy, and ast-grep tests.
- Darwin generation 1575 activated successfully at 2026-08-02 12:53 CDT.
- Fresh `codex exec` reported `gpt-5.6-sol` with High reasoning and returned `OK`; the repository Stop hook then continued because the checkout was still dirty, so the bounded smoke was interrupted after the model result.
- Live feature state reports both `multi_agent` and `multi_agent_v2` stable and enabled.
- Morning brief re-read as Terra Medium, active, local, with its next fire at 2026-08-03 07:30 CDT.
- Podcast digest re-read as Luna Max, active, local, with its next fire at 2026-08-06 15:00 CDT.
- Final `hey agent-audit-tests` and `hey agent-finish` passed repo quality, 31 agent-quality tests, instruction checks, confidence checks, and inventory checks.

## Reviews

- `hey agent-review plan --active-model-family gpt-5.6` failed twice with `RUNTIME: Authentication required`. No further retry is permitted; manual review is the fallback.
- `hey agent-review landing --active-model-family gpt-5.6` hit the same authentication blocker. Manual semantic and file diff review found no unrelated changes or unresolved findings.

## Feedback

- The heterogeneous reviewer runtime still lacks authentication on this host; the command fails before producing review findings.
- `codex exec --strict-config` cannot validate this mixed app/CLI config because CLI 0.145.0 rejects the existing desktop-owned `enabled-reasoning-efforts` key. Normal startup and the app both load it.

## Remaining work

None.

## Commits

- `b43d084e4` — native Codex model roles, documentation, and spec coverage.
