---
name: partition-by-workload-fit
description: Assigns overlapping tools or runtimes to the workloads they fit. Use when evaluating replacement, consolidation, or staged adoption across systems with different isolation, durability, or operational requirements.
---

# Partition by Workload Fit

Turn an either/or tool comparison into explicit workload assignments before deciding whether to consolidate.

## Method

1. Name the overlapping capability and the workloads that need it. Overlap is not equivalence.
2. Compare the requirements that can change the choice: execution duration, filesystem and native library access, isolation, supervision, recovery, durability, and operational maturity. Mark unsupported or unverified capabilities explicitly.
3. Assign each workload to the option that meets its requirements. Keep both only when their specialization earns the operational cost; choose one when requirements decisively exclude the other.
4. Standardize a shared boundary only where consistency helps. An adapter can connect systems without transferring ownership of every workload.
5. Choose a bounded pilot for uncertain assignments. Start project memory in isolation; expand to shared tagged context only for explicit cross-project needs.
6. State the evidence that would justify later consolidation, such as routine schema migration and recovery support. Revisit when that evidence appears rather than migrating on feature overlap alone.

## Verification

Return the workload assignments, decisive constraints, remaining unknowns, and the condition for revisiting the decision. Distinguish a recommendation from a tested capability.

For a memory pilot, evaluate recall quality before expanding scope. For repository-generating work, inspect the generated diff before any authorized publication. For runtime consolidation, verify migration and recovery support before treating maturity as established. A comparison alone does not authorize deployment or migration.

## Failure Modes

- **Everything moves into the new abstraction:** preserve deterministic sync and ETL on the durable native runtime when the new system is suited only to reasoning-heavy work.
- **Similar task trackers become interchangeable:** compare execution, isolation, supervision, and recovery roles before replacing either one.
- **The chosen runtime lacks native requirements:** use an environment that supplies the filesystem, SQLite, checkout, or long-running CLI capabilities the workload actually needs.
- **Pilot memory leaks across projects:** preserve per-project isolation until shared context has an explicit use and measured benefit.

## Provenance

Forged by Lore from four native OMP sessions (2026-07-02 through 2026-07-14), theme `partition-by-fit`. Evidence and dossier remain in the private local Lore corpus; transcript paths and project identities are intentionally omitted here.
