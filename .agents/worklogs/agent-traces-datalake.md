# Worklog: agent-traces-datalake

Status: active

## Objective

Use private Cloudflare R2 Data Catalog as the only durable agent-trace store. Stop after immutable session ingestion, read-only exploration, Darwin scheduling, and OMP consumption are exercised end to end and published.

## Decisions

- Bucket `agent-traces` remains private; catalog URI and warehouse are non-secret host settings.
- Native bytes and normalized `trajectory-v1` records share one immutable Iceberg row.
- Writer and reader are Mac-only, bucket-scoped Cloudflare user tokens encrypted to the `MacTraitor-Pro` host key.
- Queryable data uses Cloudflare server-side encryption; no local catalog, spool, transcript copy, or client-side ciphertext.
- File-backed sources are discovered by root path; Hermes/OpenCode/Amp use deterministic per-session exports; Deep Agents uses checkpoint export bytes, not the whole SQLite file.
- OMP daily introspection materializes only the latest normalized trajectory per `(source, native_id)` for the day.

## Evidence

- User-approved plan: `local://agent-traces-datalake-plan.md`.
- Run receipt: `/Users/emiller/.local/state/dotfiles-agent-runs/fd96c14e501c/20260727T182517Z-cbd2574dc8fc.json`.
- Host: `MacTraitor-Pro.local`, Darwin arm64.
- `wrangler r2 bucket catalog get agent-traces`: active catalog at `https://catalog.cloudflarestorage.com/57398029d3d0add95bdad89deaa41864/agent-traces`, warehouse `57398029d3d0add95bdad89deaa41864_agent-traces`.
- `wrangler r2 bucket domain list agent-traces`: no custom domains. `wrangler r2 bucket dev-url get agent-traces`: public URL disabled.
- Cloudflare token inventory contains only active `agent-traces-iceberg-writer` and `agent-traces-iceberg-reader`; temporary token-creation credential was revoked.
- Both encrypted secret files are mode `0600` and decrypt with the Mac host identity to 53-byte token values; plaintext was not persisted.
- `pkg-check agent-traces` green against trajectory `v0.2.0`.
- `nix build .#agent-traces` green; focused package tests: 8/8 pass.
- Live discovery smoke counted 12595 local candidates with no writes.

## Reviews

- Plan approved by user. The earlier automated reviewer was blocked by authentication; explicit user approval is the plan gate for this run.

## Feedback

- Cloudflare's R2 token dashboard cannot bucket-scope Admin tokens. Exact bucket-scoped catalog/storage policies require the documented API-token bootstrap flow; revoke the bootstrap token immediately after provisioning.
- The dashboard Copy control copies a curl command, not only the token. Clipboard consumers must parse the Bearer value without echoing input.
- Official trajectory OpenClaw listing walks `agents/*/sessions` under a state root; OMP/Pi use their own session trees with the openclaw adapter and relabeled meta source.
- Hermes listing path is a SQLite DB; per-session message export is required for native bytes and normalization.

- Package commits: `131982c5f`, `2ef51fd4d` on `agent-traces-datalake` (HEAD==origin).
- Bounded live ingest `AGENT_TRACES_SINCE=2026-07-24`: 341 rows first pass (228 normalized / 113 raw_only), hash verified, no duplicate keys.
- Second bounded pass inserted only live-changed rows; snapshot advanced as expected.
- Reader token: table scan OK; namespace create denied 403.
- DuckDB attach with reader listed sources; write path not granted.
- Catalog compaction enabled at 128 MB target.
- `hey check` Darwin green after formatting. `darwin-rebuild switch` activated `org.nixos.agent-traces` at 03:30 with secret path env only.
- OMP materialize smoke for 2026-07-26: 28 temporary trajectory files, meta-leading JSON, cleaned with tempdir.
- Full first launchd kick still running historical backfill (stdout buffered until PYTHONUNBUFFERED rebuild).

## Remaining work

- Wait for first full launchd backfill JSON summary; optional browser marimo pass.
- Merge branch when backfill completes.

## Commits

- `131982c5f` feat(agent-traces): ingest sessions into R2 Iceberg
- `2ef51fd4d` feat(agents): schedule Iceberg ingestion and reuse it
