# flue-evlog

Flue model accounting through evlog drains. This private, local npm package
exports compiled ESM and TypeScript declarations. It can move to its own repo
without importing anything from dotfiles. No registry publication is configured.

Supported and tested versions: Node 22.23.2, `@flue/runtime` and `@flue/cli`
1.0.0-beta.9, and evlog 2.33.1. Peer versions are exact because these contracts
are still changing.

## Use in a Flue application

Register once in `app.ts`, not inside an agent initializer. Flue's CLI awaits
instrumentation disposal. An embedded host must await `telemetry.dispose()`
after its runs finish and before exiting.

```ts
import { flue } from "@flue/runtime/routing";
import { writeToFs } from "evlog/fs";
import { installFlueEvlog } from "flue-evlog";

const telemetry = installFlueEvlog({
  service: "my-flue-app",
  environment: "development",
  drain: ({ event }) => writeToFs(event, { dir: ".evlog/logs", pretty: false }),
});

export default flue();
```

The adapter emits `WideEvent` records directly through evlog's public
`DrainContext` contract. It does not call `initLogger`, change the host's global
drain, or use evlog internals. Accounting bypasses global logger enablement,
sampling, redaction, enrichers, and plugins. The explicit field allowlist excludes
prompts, responses, reasoning, tool arguments/results, and raw errors. Supply only
non-sensitive `service`, `environment`, and metadata labels. Apply any additional
application redaction inside your drain.

`drain` must acknowledge persistence, or a buffered drain must supply an awaited
`flush`. Disposal drains pending events, flushes, then writes and flushes the
shutdown record. Rejected writes or flushes reject disposal. The adapter does
not retry failed writes or hide them behind a clean shutdown record. The returned
`drain` can also serialize application HTTP logs to the same destination.

An empty buffer is not proof of delivery. Some evlog pipelines resolve `flush()`
after dropping events. Retain their drop/error notifications and make your flush
wrapper reject if any accounting event was lost. Passing such a pipeline's
unmodified `flush` is not a persistence guarantee.

## Read accounting

```ts
import { readLedger, summarize } from "flue-evlog/ledger";

const report = summarize(await readLedger(".evlog/logs"));
if (!report.complete) throw new Error("Incomplete model accounting");
console.log(report.groups);
```

The `flue.evlog.v1` schema tracks runtime IDs, durations, outcomes, model usage,
and optional caller-supplied provenance. Only terminal model turns count toward
totals. Compaction and operation aggregates overlap those turns and are not
added again. The reader rejects malformed or conflicting records and deduplicates
identical event IDs. Every accounting record has an adapter-owned sequence number;
shutdown certifies the final count. The summary rejects gaps, including missing
whole start/end pairs or export files, and accepts reordered duplicate downloads.
It cannot discover an execution omitted in its entirety without an external run
inventory. Unsequenced pre-release exports are rejected, not silently upgraded.

Model calls open on `turn_request`, including compaction and split-prefix calls.
Tool IDs are scoped by turn, operation, and session; caller shell tools need no
model turn. Workflow-owned turns are attributed to `workflow:<name>` when Flue
does not supply an agent name.

All-zero usage is unknown because pi-ai cannot distinguish a missing provider
receipt from a genuine zero. Zero cost is also unknown rather than evidence of a
free call. Either condition makes `complete` false. Unknown costs produce
`estimatedCostUsd: null` and an `unknownCost` count while known token totals remain
available. This conservatively rejects genuinely zero-usage or free calls too.
Recovered tool errors remain visible without making complete accounting fail.

This is application accounting, not billing reconciliation. Flue beta.9 does not
expose separate reasoning tokens or every provider retry. Costs are estimates.
The package does not repair code, grant tool permissions, or publish changes.

## Develop or extract

From this directory:

```sh
npm ci --ignore-scripts
npm run check
npm pack
```

Tests use the real Flue CLI with a local fixture provider. No paid model calls or
provider credentials are needed. Tests cover exact token totals, content
exclusion, failures, buffered drains, and unchanged host logging policy.

The dotfiles consumer installs this package with `file:../packages/flue-evlog`
and `install-links=true`, so it tests the packed package rather than a source
symlink. Build this package before running `npm ci --prefix .flue --ignore-scripts`.
Reinstall the consumer after changing the package. `hey check packages/flue-evlog`
builds and tests both automatically in a disposable checkout.

To extract later, move this directory, retain the license, choose a registry name,
remove `private` only when publishing is intended, and replace the consumer's
`file:` dependency with the published version. Retention, CI metadata, repair
permissions, and the observability score remain application policy.
