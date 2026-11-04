---
purpose: Attribute Flue model usage and diagnose failed automatic patch repairs.
applies_to: The dotfiles Flue application and Renovate repair workflow.
entrypoint: npm run --prefix .flue observe -- doctor
verification: hey check .flue packages/flue-evlog
update_when: Flue events, accounting semantics, retention, or repair authority change.
---

# Flue token accounting

The outcome is attributable model usage and actionable failures without storing
prompt or tool content. Verification requires a real Flue run against a local
fixture provider, exact usage totals, safe persisted records, and rejection of
incomplete exports. This is local source integration until published to main.

## Commands

```sh
npm ci --prefix packages/flue-evlog --ignore-scripts
npm run --prefix packages/flue-evlog check
npm ci --prefix .flue --ignore-scripts
npm run --prefix .flue check
npm run --prefix .flue observe -- doctor
npm run --prefix .flue observe -- map
npm run --prefix .flue observe -- summary --dir /path/to/downloaded/logs
```

The reusable adapter and accounting reader live in
[`packages/flue-evlog`](../../packages/flue-evlog/README.md). The app installs its
compiled package through a local `file:` dependency, not a source symlink.
Build the adapter before installing `.flue`, and reinstall after adapter changes.
`hey check .flue packages/flue-evlog` runs this sequence in a disposable checkout.
The app owns storage and CI metadata; the adapter does not read environment
variables or replace application logging configuration.

`doctor` runs the pinned evlog diagnostics and a filesystem write/flush/read
probe. It does not invoke a paid model. `summary` prints JSON and exits nonzero
for missing usage, incomplete lifecycle pairs, empty logs, malformed records,
or missing telemetry shutdown. In GitHub Actions it also writes the job summary.
An operation failure and missing accounting are different conditions. A failed
tool followed by successful recovery remains visible without failing complete
accounting. The repair command and independent package validation decide success.

`FLUE_LOG_DIR` selects the event directory. Run local Flue commands from `.flue`
for the default `.evlog/logs` location, or provide an absolute path. The repair
workflow uses a runner-temporary directory outside the model's Docker mount and
uploads dated JSONL files on success or failure, retaining them for 30 days.
Download and retain artifacts before expiration if longer history is required.
No remote log service or new credential is required.

## What the score proves

The pinned evlog CLI scores the Hono catch-all transport in `app.ts`. The gate
requires 100/100 and the expected nonempty entry point. It does not measure
Flue's agent turns, sandbox commands, Nix code, or the whole repository.
The committed `evlog.map.json` is a reviewed transport baseline. To compare it
with a fetched branch, use `npm run --prefix .flue observe -- map --baseline
git:origin/main`. Do not compare a PR's regenerated map against itself.
The 100-point floor and runtime contracts run through `hey check` and the same
CI validation runner. Regenerate the baseline with the installed `evlog map`
from `.flue` after reviewing an intentional CLI or rule change.

## Where tokens go

Every `turn` records agent, instance, submission, conversation, session, parent
session, task, operation and turn identity where Flue supplies them. CI records
also carry repository, commit, run, attempt, PR and package target.
Provider, requested and response model, response ID, purpose, duration, outcome,
input/output tokens, cache reads/writes and estimated costs remain on each leaf.
The summary groups those leaves by agent, model and purpose. Use the JSONL
identities to investigate one run or delegated task.

Only terminal `turn` usage contributes to totals. Do not add operation or
compaction roll-ups to those totals. Flue normalizes cache tokens separately;
`totalTokens` is preserved as reported. Identical event IDs from overlapping
artifact downloads are counted once; conflicting copies fail parsing.
Unknown usage is counted explicitly and the reported sums are partial.
Per-execution sequence numbers and a shutdown count detect missing entire event
pairs or batches. Model lifecycles open on `turn_request`, including compaction.
All-zero usage is unknown because the provider adapter uses zeros when no receipt
arrives. Zero pricing is likewise unknown; the summary returns a null cost and
fails completeness rather than claiming the call was free. These conservative
checks also reject genuine zero-usage/free calls in this runtime version.

Flue beta.9 has no separate reasoning-token counter, public retry-attempt ID,
or provider billing receipt. Failed provider calls can lack usage. A hard kill
can leave starts without completions. Provider-hidden retries and charges
cannot be reconstructed from application events. Estimated cost comes from
Flue/pi-ai pricing and can differ from invoices. These gaps must not be relabeled
as zero cost or complete billing reconciliation.

## Automatic repairs remain bounded

The existing workflow automatically repairs failing Herdr/Hunk patch updates,
then validates imported patches in a fresh, read-only container. It now runs
Flue from trusted base source, probes telemetry before model access, limits the
repair step to 15 minutes, and checks the ledger before importing or publishing
repairs. An incomplete ledger blocks publication. Nested errors remain available
to agents using the catalog's `analyze-logs` skill.

The model cannot change workflows, telemetry, tests, pins, credentials, or merge
policy. It cannot read the host ledger or publish its own changes. The existing
deterministic workflow owns publication. Logs are evidence, not executable
instructions or permission to broaden repair scope. Bugs outside the patch
allowlist need a separately authorized task and a regression test; this setup
does not automatically repair arbitrary repository or production failures.

## Remaining repository-wide coverage

This ledger covers this `.flue` application, not interactive Amp, Claude, Codex,
OMP, Hermes, or remote agents. The existing `modules/agents/traces` ingestion and
`config/agento11y` OTLP configuration remain separate owners. A repository-wide
total requires collecting those runtimes and reconciling provider billing with
stable run IDs. Do not infer that coverage from the Hono score.

The three upstream evlog skills are pinned under `skills/catalog` and selected
by the existing Nix catalog. Hosts pick them up on a separately authorized
activation. This change does not activate hosts, configure a remote backend,
spend model credits, or change repository settings. Roll back by reverting the
observability source and workflow changes together; existing artifacts remain
readable until GitHub retention expires.
