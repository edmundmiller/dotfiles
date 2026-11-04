# Framework Wiring

The audit pipeline is the same shape in every framework: register `auditEnricher()`, wire a main drain, and add an audit-only drain. Pick the section that matches the user's stack.

The HTTP examples below require a trusted authentication proxy. It must strip any incoming `x-tenant-id`, authenticate the caller, verify their membership in the selected tenant, and inject that tenant's ID. Reject unauthenticated or unauthorized requests before they reach the application. Block direct access to the application so clients cannot bypass the proxy. Without these guarantees, replace the header lookup with application-owned authenticated, membership-checked tenant resolution. A client-supplied header is not tenant authorization.

## Hono

```ts
import { Hono } from "hono";
import { evlog, type EvlogVariables } from "evlog/hono";
import { auditEnricher, auditOnly, signed } from "evlog";
import { createAxiomDrain } from "evlog/axiom";
import { createFsDrain } from "evlog/fs";

const main = createAxiomDrain({ dataset: "logs" });
const auditSink = auditOnly(signed(createFsDrain({ dir: ".audit/" }), { strategy: "hash-chain" }), {
  await: true,
});

const app = new Hono<EvlogVariables>();
app.use(
  evlog({
    // Requires the trusted auth proxy described above: strip client headers,
    // authenticate, check tenant membership, inject ID, and block proxy bypass.
    enrich: (ctx) => auditEnricher({ tenantId: (c) => c.headers?.["x-tenant-id"] })(ctx),
    drain: async (ctx) => {
      await Promise.all([main(ctx), auditSink(ctx)]);
    },
  })
);
```

## Express

```ts
import express from "express";
import { evlog } from "evlog/express";
import { auditEnricher, auditOnly, signed } from "evlog";
import { createAxiomDrain } from "evlog/axiom";
import { createFsDrain } from "evlog/fs";

const main = createAxiomDrain({ dataset: "logs" });
const auditSink = auditOnly(signed(createFsDrain({ dir: ".audit/" }), { strategy: "hash-chain" }), {
  await: true,
});

const app = express();
app.use(
  evlog({
    // Requires the trusted auth proxy described above: strip client headers,
    // authenticate, check tenant membership, inject ID, and block proxy bypass.
    enrich: auditEnricher({ tenantId: (ctx) => ctx.headers?.["x-tenant-id"] }),
    drain: async (ctx) => {
      await Promise.all([main(ctx), auditSink(ctx)]);
    },
  })
);
```

## Next.js (App Router)

```ts
// lib/evlog.ts
import { createEvlog } from "evlog/next";
import { auditEnricher, auditOnly, signed } from "evlog";
import { createAxiomDrain } from "evlog/axiom";
import { createFsDrain } from "evlog/fs";

const main = createAxiomDrain({ dataset: "logs" });
const auditSink = auditOnly(signed(createFsDrain({ dir: ".audit/" }), { strategy: "hash-chain" }), {
  await: true,
});

export const { withEvlog, useLogger } = createEvlog({
  service: "my-app",
  // Requires the trusted auth proxy described above: strip client headers,
  // authenticate, check tenant membership, inject ID, and block proxy bypass.
  enrich: auditEnricher({ tenantId: (ctx) => ctx.headers?.["x-tenant-id"] }),
  drain: async (ctx) => {
    await Promise.all([main(ctx), auditSink(ctx)]);
  },
});
```

## Standalone scripts / queue workers / CLIs

No request → no enricher needed. `audit()` (or `withAudit()`) replaces `log.audit()`:

```ts
import { initLogger, audit } from "evlog";
import { signed } from "evlog";
import { createFsDrain } from "evlog/fs";

initLogger({
  env: { service: "billing-worker" },
  drain: signed(createFsDrain({ dir: ".audit/" }), { strategy: "hash-chain" }),
});

audit({
  action: "cron.cleanup",
  actor: { type: "system", id: "cron" },
  target: { type: "job", id: "cleanup-stale-sessions" },
  outcome: "success",
});
```

## Notes that apply everywhere

- Failure isolation between drains comes from `initLogger({ drain: [...] })` invoking each drain independently. If you instead use `Promise.all`, a single rejection takes the others down. Wrap in `Promise.allSettled` and log failures, or stick with the array form.
- `await: true` on `auditOnly` makes the wrapped drain block the request until the event is flushed. Use it for the tamper-evident drain so you don't lose audits on crash; the queryable drain can stay async.
- An audit recorded inside `log.fork()` is drained by the child event, not the request. `await log.fork(label, fn)` when that audit must be written before the handler returns. An unawaited fork still drains, and on `waitUntil` runtimes it is registered with `waitUntil` when `log.fork()` is called.
- For multi-process deployments behind hash-chain, persist `state.{load,save}` (Redis is the common choice) so the chain survives restarts and rolling deploys.
