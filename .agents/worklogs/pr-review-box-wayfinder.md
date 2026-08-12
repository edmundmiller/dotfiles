Status: complete

## Objective

Create, verify, land, and dispatch research for a Wayfinder map whose destination is a decision-complete high-throughput GitHub PR Review Box workflow specification.

## Decisions

- Chart decisions only; do not implement the review workflow or replace MDR's separate roadmap.
- Preserve the unrelated edits in `config/agents/rules/15-agent-behavior.md` and `config/agents/rules/16-autonomous-goal-progress.md`.

## Evidence

- Fresh import of `.beads/issues.jsonl` reported 672 records.
- `br dep cycles --json` reported zero cycles.
- `br ready --parent dotfiles-esav --unassigned --json` returned only the two HITL frontier tickets after research dispatch.
- Structural audit found one map, ten children, and the expected Wayfinder labels.
- Both research tickets were resolved with evidence and indexed under the map's `Decisions so far`.
- `hey agent-audit-tests` passed.

## Reviews

- Plan resolved with the user through Wayfinder, Grilling, and Domain Modeling.
- `/root/research_ghui_herdr` resolved the promotion seam around a ghui action, local bridge, and existing `pi-herdr` orchestration.
- `/root/research_github_pending_reviews` resolved the two-step human authority boundary and current GitHub review API contract.

## Feedback

- Current `br` refuses `sync --import-only` when the configured ignored database is missing. An isolated tracker plus an additive JSONL patch avoided force-overwriting shared issue state.

## Remaining work

- None.

## Commits

- `docs(review): chart PR review workflow decisions`
