# Worklog: omp-ttsr-thin-harness

Status: complete

## Objective

Define an OMP-first thin-harness architecture based on Time-Traveling Stream
Rules (TTSR), record it in an ADR, and leave an evidence-backed staged migration
plan. Stop before migrating the shared agent-rule bundle or rebuilding a host.

## Decisions

- Treat TTSR as OMP's dormant corrective layer, not as a replacement for
  deterministic enforcement, task-triggered skills, or repository routing.
- Pilot the architecture in OMP before changing Codex or Pi instruction wiring.
- Preserve unrelated edits in shared rules 15 and 16.

## Evidence

- OMP public TTSR documentation and upstream implementation documentation.
- Live `omp/17.2.11` `ttsr` CLI help and registered-rule inventory.
- Live `omp ttsr test` fixtures exposed an overlapping `git commit` match and a
  false positive for `rg jj README.md`; clean negatives included `git status`
  and `gh pr view 42`.
- Read-only review of relevant notes in `/Users/emiller/obsidian-vault`.
- Current shared-rule and OMP-rule wiring inspected in this checkout.
- Added ADR 0010 to the canonical documentation index.
- `oxfmt --check` passed for the ADR and worklog.
- `python3 -m unittest tests/test_agent_instruction_wiring.py
tests/test_agent_rules.py` passed 9 tests.
- `git diff --check` passed for the added artifacts.

## Reviews

Plan review: user selected TTSR as the likely OMP mechanism and requested this
ADR. No cross-model review requested.

## Feedback

The Obsidian CLI was installed but did not return while Obsidian was unavailable
or unresponsive. Vault research used bounded read-only `rg` and targeted file
reads as the documented fallback.

## Remaining work

None for the ADR goal. The migration phases remain intentionally unimplemented
and are tracked in ADR 0010.

## Commits

Recorded in Git history during closeout.
