# Worklog: openwiki-discord-source

Status: complete

## Objective

Add a bounded Discord source for personal OpenWiki, backed by the existing local Discrawl archive; prove connector parsing, scope, state, packaging, and a real local pull. Stop after the personal source is configured and exercised, or record the exact runtime blocker.

## Decisions

- Use Discrawl's local SQLite archive through its JSON CLI, not Discord user-token scraping.
- Follow Slack synthesis policy while retaining Discord-specific source evidence.
- Preserve unrelated `.beads/issues.jsonl` and `.github/workflows/openwiki-update.yml` changes.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin arm64.
- `discrawl status --json`: current local archive, 192 messages across 34 channels; live Discord token disabled.
- Official Discord docs require bot/OAuth authorization; message content can be empty without Message Content intent.
- Red: 5 connector tests failed on the expected missing `discord.ts` module.
- Green: typecheck plus 81 focused tests passed against the patched upstream checkout.
- Real isolated smoke: Discrawl local DM scope wrote 36 messages plus manifest/state, all mode `0600`, with only the 13 allowlisted fields.
- `pkg-check openwiki`: patch stack applied; typecheck and 81 focused tests passed.
- `nix build .#openwiki`: `/nix/store/ak0s473h3cwkzbjjkqr90yppr02jlibc-openwiki-0.2.0`.
- Darwin activation succeeded. Active packaged connector exists and `openwiki ingest discord --print` resolved `discord-1`, queried the explicit personal guild, and skipped cleanly because the current archive has no messages in that guild.
- `hey check`: all Darwin checks passed; its formatting/pre-commit changed-file selectors were no-ops, so they are not counted as artifact verification.
- `hey agent-audit-tests`: `PASS test-confidence`.
- `nix develop -c true` generated the worktree hook config; rerun `hey agent-finish` passed repo quality, agent quality, inventory drift, and test confidence.

## Reviews

- Plan review: attempted with `hey agent-review plan --active-model-family gpt-5`; blocked by `RUNTIME: Authentication required` before review output.
- Landing review: attempted with `hey agent-review landing --active-model-family gpt-5`; blocked by `RUNTIME: Authentication required` before review output.

## Feedback

- Detached worktrees need `nix develop -c true` once to generate `.pre-commit-config.yaml`; without it, `hey agent-finish` cannot run changed-file hooks.

## Remaining work

None.

## Commits

- `feat(openwiki): add Discord source` (this change).
