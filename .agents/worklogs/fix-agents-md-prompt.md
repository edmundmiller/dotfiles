# Worklog: fix-agents-md-prompt

Status: complete

## Objective

Install the AI Hero progressive-disclosure repair prompt as an OMP prompt template, run it through a sub-agent against this repository, resolve its findings, and land the verified result upstream.

## Decisions

- Preserve the article prompt's requested workflow and wording; add only the metadata or repository-specific context required for reliable OMP execution.
- Preserve unrelated edits already present in `config/agents/rules/15-agent-behavior.md` and `config/agents/rules/16-autonomous-goal-progress.md`.
- User chose the accepted ADR 0001 policy for both delegated contradictions: agents use `hey re` / `hey rebuild` for Darwin activation and `hey skills-update` / `hey skills-sync` for skills-catalog updates.
- Keep root `AGENTS.md` as the task router and move repository-wide safety, documentation, tooling, and landing detail to `docs/agent-guardrails.md`.

## Evidence

- Source prompt: https://www.aihero.dev/a-complete-guide-to-agents-md#fix-a-broken-agentsmd-with-this-prompt
- Host before runtime work: `MacTraitor-Pro.local`, Darwin arm64.
- Red/green: the focused wiring test first failed because `config/omp/commands/fix-agents-md.md` was absent, then passed after source and Home Manager wiring were added.
- `python3 -m unittest tests.test_agent_instruction_wiring`: 3 tests passed.
- All four `modules/agents/omp/test-*.sh` configuration checks exited successfully.
- `hey check`: all Darwin checks passed.
- `FLAKE_DIR="$PWD" hey re`: installed the staged checkout successfully.
- Runtime source and installed-template SHA-256 both equal `64d2d16235a0457787f29aaf446230358f61480025a101453b6f9d9af1302449`.
- OMP RPC `get_available_commands` returned `fix-agents-md` with the expected description and `source: file`.
- Delegated prompt run first stopped on two policy contradictions, then resumed with the user's choices and completed the progressive-disclosure refactor.
- Red/green policy regression: the all-`AGENTS.md` test failed on direct commands in `config/AGENTS.md` and `skills/AGENTS.md`, then passed after nested guidance was aligned to `hey`.
- `python3 -m unittest tests.test_agent_instruction_wiring`: 4 tests passed.
- Canonical-doc frontmatter, route-target existence, rejected-command search, and `git diff --check` passed.
- Final `hey check`: all Darwin checks passed.

## Reviews

- A delegated sub-agent ran the installed prompt against root `AGENTS.md`, made no edits, and stopped on the two policy contradictions required below.
- After the user chose `hey` for both policies, the same sub-agent relocated root detail, aligned nested `AGENTS.md` files, and reported no redundant or vague deletion candidates.
- Main-agent review restored documentation and OpenWiki regeneration rules that the delegated relocation had accidentally omitted.

## Feedback

- Root and nested `AGENTS.md` files had drifted from accepted ADR 0001; the regression test now prevents those two direct-command instructions from returning.

## Remaining work

None.

## Commits

- `feat(omp): add AGENTS.md repair command`
- `docs(agents): apply progressive disclosure`
- After landing: `agent-work/fix-agents-md-prompt`.
