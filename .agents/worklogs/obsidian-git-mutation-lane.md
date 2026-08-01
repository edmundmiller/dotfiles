# Worklog: obsidian-git-mutation-lane

Status: active

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
- Runtime acceptance and remote equality remain pending.

## Reviews

- `hey agent-review plan --active-model-family gpt-5 ...` could not run: `Authentication required`.
- Per retry policy, the same unavailable review route was not retried.

## Feedback

- Pending.

## Remaining work

- Commit implementation, rebuild/reload, trigger ingestion, and verify runtime isolation.

## Commits

- `6f8cdc5c2 test(openwiki): capture canonical checkout mutation`
