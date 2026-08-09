---
description: Triage an OMP Auto QA grievance and patch its root cause.
argument-hint: [id|tool] [--clean]
---

Triage one OMP Auto QA grievance.

Selector: `$ARGUMENTS`

1. Run `omp grievances list --limit 100 --json`. Exact id or tool match if given; otherwise the newest actionable grievance owned by this repository. Stop clearly if none match.
2. `pushed` is delivery state, not resolution. Read the full report and fix only the tool's owning source—never another repository just because the grievance was recorded here.
3. Reproduce before editing. Follow loaded rules and relevant skills; fix the root cause. No compensating wrappers or call-site exceptions unless ownership requires one.
4. Re-run the focused behavioral reproduction, then the owning subsystem's required checks. Do not weaken tests or verification assets.
5. Report id, owner, reproduction, changed files, and fresh verification evidence. Keep the grievance unless `--clean` was supplied; with `--clean`, run `omp grievances clean --id <id>` only after the fix is verified and landed.
