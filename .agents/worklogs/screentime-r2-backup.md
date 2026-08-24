# Worklog: screentime-r2-backup

Status: blocked

Repository changes are ready to land; runtime completion awaits explicit credential-creation confirmation.

## Objective

Archive every local macOS `/app/usage` record into an append-only SQLite database keyed by `ZUUID`, run the archive and an encrypted restic backup weekly through a Nix-managed LaunchAgent on `mactraitorpro`, and store snapshots in a dedicated private Cloudflare R2 `screentime-backups` bucket. Stop before persistent credential creation for explicit confirmation, or on an active-account or target mismatch.

## Decisions

- Keep the archive and restic repository outside the Obsidian vault and Git.
- Use a dedicated R2 bucket and credential boundary; do not reuse `agent-traces` or an existing restic repository.
- Do not add public access, lifecycle deletion, pruning, or retention deletion.
- Verify a real launchd run and a representative temporary restore; configuration evaluation alone is insufficient.

## Evidence

- `hostname` returned `MacTraitor-Pro.local`; `uname -a` reported Darwin arm64.
- Live checkout was dirty with unrelated changes, so work moved to this isolated worktree at `origin/main` revision `aeee57f6c62502e2fcc05a8e97bc39dc4c6a31e8`.
- Current `/app/usage` rows have non-empty unique `ZUUID` values.
- Live Wrangler readback identified the expected personal Cloudflare account and showed no existing `screentime-backups` bucket.
- Agent run receipt: `/Users/emiller/.local/state/dotfiles-agent-runs/cdff133eb1b1/20260823T033205Z-d287c9a27be8.json` with `local-only` authority.
- CLI fixture test passed through the packaged Nix derivation, including UUID idempotency, append-only first-seen rows, missing-UUID failure, Keychain/restic isolation, JSON snapshot readback, and secret-free output.
- Darwin evaluation passed for the packaged CLI, exact source/archive/R2 arguments, Sunday 23:55 schedule, log paths, and no `RunAtLoad`.
- Real archive run inserted 5,751 rows; source and archive both had 5,751 distinct UUIDs and identical min/max timestamps. `PRAGMA quick_check` returned `ok`; the directory/file modes were `0700/0600`; an immediate second run inserted zero rows.
- `hey check` and `hey re` passed. Deployed plist readback showed the exact program, arguments, Sunday 23:55 trigger, log paths, and no `RunAtLoad`; `launchctl` showed `runs = 0` and `last exit code = (never exited)` before credentials.
- The deployed CLI added 27 newly observed records and advanced the private local archive to 5,778 rows. Current source and archive both contain 5,778 rows and distinct UUIDs, with zero source UUIDs missing from the archive; archive bounds are `806724654.0` through `809150686.0`.
- Immediately before the external create, Wrangler reverified `edmund.a.miller@gmail.com` and account `57398029d3d0add95bdad89deaa41864`, proved the target absent, created `screentime-backups`, and reread it as an empty WNAM Standard bucket. `r2.dev` is disabled, no custom domains exist, and the only lifecycle rule is Cloudflare's default incomplete-multipart abort rule.

## Reviews

- User confirmed four observable TDD seams and Sunday 23:55 local scheduling.
- The explicit goal, credential stop, and confirmed seams are the authoritative plan gate. Persistent credential creation remains unapproved.
- All three expected Keychain services are absent. The 1Password CLI authorization attempt timed out, so no 1Password item state was inferred and no credential was created.
- Final blocker audit: the source/archive remain synchronized at 5,778 rows (`inserted: 0`), all three Keychain services remain absent, and launchd reports `runs = 0` / `last exit code = (never exited)`. The explicit credential-creation confirmation has remained absent for three consecutive goal turns.
- Closeout validation on 2026-08-24 passed the packaged CLI check, Darwin assertions, `git diff --check`, `hey agent-audit-tests`, and the full Darwin `hey check` gate.
- The `code-review` skill requires a committed fixed-point diff and could not review this `local-only`, uncommitted run. Fallback `sem diff` review found and resolved timestamp JSON mislabeling, a missing-UUID race, and pre-existing archive permission drift.
- Done review found that the CLI accepted the dedicated bucket under any R2 account hostname. A red/green regression now proves it accepts only account `57398029d3d0add95bdad89deaa41864`.

## Feedback

None.

## Remaining work

- Obtain explicit credential-creation confirmation.
- Create the bucket-scoped token, 1Password/Keychain entries, and encrypted restic repository; verify a real launchd run and representative restore.

## Commits

Pending closeout commit.
