# Worklog: obsidian-git-mutation-lane

Status: complete

## Objective

Run scheduled OpenWiki ingestion outside `/Users/emiller/obsidian-vault`, publish through bounded non-force remote-main retries, reload launchd, and prove canonical main stays unchanged and clean.

## Decisions

- Treat GitHub's non-force ref update as the serialized remote mutation lane.
- Keep the live Obsidian vault read-only to scheduled Git processes.
- Preserve failed/conflicted mutations in the isolated scheduler clone for recovery.

## Evidence

- `python3 -m unittest tests/test_openwiki_git_mutation_lane.py`: pass.
- `nix develop --command pkg-check openwiki`: 14 files, 139 tests pass.
- `nix build .#packages.aarch64-darwin.openwiki --no-link`: pass.
- `hey agent-audit-tests`: `PASS test-confidence`.
- `hey agent-finish`: all Darwin checks and 17 quality tests pass.
- `hey re`: activation passed; launchd plist now uses `~/.local/state/openwiki/obsidian-vault` at 02:00.
- Manual `launchctl kickstart`: isolated ingestion committed and published through a concurrent Flue-audit update; live vault stayed clean and unmoved until the explicit final fast-forward.
- Isolated OpenWiki `HEAD`, tracking ref, and authoritative remote all reached `f2838c1c4c`.

## Reviews

- `hey agent-review plan --active-model-family gpt-5 ...` could not run: `Authentication required`.
- Landing review failed at the same authentication boundary.
- Per retry policy, the same unavailable review route was not retried.

## Feedback

- The first runtime trigger exposed missing `git-lfs` in the scheduler PATH; the focused test and runtime inputs now cover it.

## Remaining work

- None for the OpenWiki scheduler lane.

## Commits

- `6f8cdc5c2 test(openwiki): capture canonical checkout mutation`
- `b546b98ac fix(openwiki): isolate scheduled Git mutations`
- `ab9423eda docs(agent): record mutation lane verification`
- `b56b09aa0 fix(openwiki): include Git LFS in scheduler runtime`
