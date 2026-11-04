---
name: auditing-performance
description: Audits application hot paths with reproducible measurements and correctness checks. Use for evidence-based performance audits, slow request investigations, redundant database reads or parsing, and unnecessary sequential async calls. Not for general code cleanup or unsupported speedup claims.
compatibility: portable
metadata:
  inspiration: https://x.com/_dylanga/status/2117400205314421058
  related-post: https://x.com/_dylanga/status/2117099613022732412
---

# Auditing performance

Find expensive work on exercised paths, test one hypothesis at a time, and report
only improvements the measurements support. The linked posts supply candidates,
not evidence about the current application.

## Scope and authority

- An audit is read-only unless the user also requests fixes. Local profiling and
  disposable fixtures are allowed; preserve existing work.
- With fix authority, make small local changes and verify them. Do not turn an
  audit into a rewrite, a dependency upgrade, or a general cleanup.
- Use disposable local data for experiments. Production load tests, shared-data
  writes, migrations, deployments, and publication require explicit authorization.
  Even `EXPLAIN ANALYZE` executes its query and can consume substantial resources.
- If representative data, credentials, or profiling tools are missing, continue
  with available evidence. Label static candidates as unmeasured and name the
  missing check. Never substitute invented timings or production experiments.

## Workflow

1. **Choose the workload.** Identify the user-visible operation, its entrypoint,
   and a metric such as latency, throughput, CPU time, allocations, or database
   bytes read. Read callers and contracts before changing the implementation.
   Use traces, profiles, query statistics, or a representative local run to show
   that the suspected work executes frequently or dominates a slow operation.

2. **Capture the baseline before editing.** Record the revision, command, runtime,
   fixture size and distribution, concurrency, cache state, and measurement scope.
   Prefer existing benchmarks. Repeat runs after warmup where appropriate; keep
   cold-start and warmed results separate. Record sample count and variation,
   not just the fastest run. Measure tail latency only with enough observations
   to support the percentile. Check output correctness as part of the baseline.

3. **State a falsifiable hypothesis.** Name the repeated or oversized work, its
   cost evidence, the smallest proposed change, and the observation that would
   disprove it. Rank candidates by measured contribution and regression risk.
   Search hits alone do not establish a hot path. Start with one candidate.

4. **Evaluate the change.** For an audit-only request, report the evidence and
   proposed experiment without editing application code. For an authorized fix,
   preserve the public contract and change one cause at a time. Check the traps
   below before applying a familiar optimization.

5. **Compare equivalent runs.** Rerun the baseline command with the same inputs,
   environment, load, and cache conditions. Interleave before and after runs when
   drift is likely. Report absolute values, units, sample counts, and variation.
   Treat a difference within measurement noise as inconclusive. A microbenchmark
   establishes only the local cost; measure the affected operation before claiming
   an end-to-end speedup. Inspect CPU, memory, I/O, or dependency load when the
   change may move costs rather than remove them.

6. **Verify behavior and stop.** Exercise success, error, and boundary cases that
   could distinguish the original from the changed behavior. Run existing tests;
   keep a regression test only for a caller-visible contract at risk. If the
   improvement is absent or correctness regresses, revert only the experimental
   edits you own. Keep a safe fix only when evidence supports its intended benefit.
   Remove disposable probes and fixtures. Stop when the requested scope is covered
   or remaining candidates lack enough evidence to justify changes.

## Candidates and traps

| Candidate                                   | Evidence to collect                                                                            | Contract to preserve                                                                                                                                                                                                                                                                                 |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fetching whole rows for a few fields        | Actual query projection, returned bytes, row count, decoding cost, and caller field use        | ORM identity fields, serializers, authorization checks, hooks, and later lazy reads. A smaller projection must not create N+1 queries.                                                                                                                                                               |
| Repeated `new URL()` parsing                | Parse count and profile cost for the same input during one operation                           | Relative URL bases, validation, encoding, normalization, and mutation of URL objects. Parse once where ownership is clear; do not replace a parser with unchecked string splitting or an unbounded global cache.                                                                                     |
| Repeated regex construction                 | Construction cost on the exercised path, separated from matching cost                          | JavaScript `g` and `y` regexes mutate `lastIndex`. Shared instances can change results across calls or reentrant use. Dynamic patterns need their inputs preserved. Moving a regex cannot fix catastrophic backtracking.                                                                             |
| Reading one key from a large `jsonb` value  | Actual query plan, representative value sizes, buffers or I/O, and TOAST cost where observable | A new column needs equivalent null, missing-key, type, and update semantics. Plan backfill, consistency, indexes, rollout, and rollback. An expression index may help filtering but does not automatically avoid detoasting projected values. Do not infer physical bytes read from JSON size alone. |
| Independent async work awaited sequentially | Dependency relationships, timeline overlap, end-to-end latency, and downstream capacity        | Ordering, transactions, rate limits, connection pools, error handling, and cancellation. `Promise.all` rejection does not cancel siblings. Bound concurrency for variable-size workloads and test partial failure.                                                                                   |

Skip candidates that do not apply to the application. Do not force every row of
the table into a finding or remove useful validation just to reduce work.

## Report

Keep the result concise and reproducible. For each material finding, include:

- The operation and code location, with observed evidence separated from inference.
- The hypothesis and disposition: measured improvement, rejected, inconclusive,
  or unmeasured candidate.
- Before and after values with units, samples, variation, and the exact command
  and fixture needed to reproduce them. Omit fabricated comparisons for unrun work.
- Correctness checks, remaining uncertainty, and costs shifted to other components.
- What changed locally, what was reverted, and any approval or deployment still
  required. Link the originating request when recording a commit or durable report.

No findings is a valid result. Passing tests prove only the cases they exercise;
they do not prove a speedup. Faster isolated code does not prove a faster product.
