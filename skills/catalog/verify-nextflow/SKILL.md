---
name: verify-nextflow
description: >
  Quantitative verification for Nextflow and nf-core changes: nf-test pass
  counts, nextflow lint clean, nf-core pipeline lint. Use after editing .nf
  files, modules, subworkflows, workflows, or pipeline config — before commit,
  handoff, or claiming a Nextflow/nf-core change done.
---

# Verify Nextflow

Numeric pass/fail only. "Looks right" is not a result.

## 1. Record expected numbers BEFORE the change

```bash
nf-test list | wc -l        # expected test count
```

Adding behavior? Expected count goes up. Removing tests needs explicit justification.

## 2. Run checks (exact commands)

```bash
# Tests — scope to what changed, full suite before handoff
nf-test test                        # or: nf-test test tests/modules/<name>
# PASS: "FAILED: 0" and passed count == expected from step 1

# Nextflow lint (Nextflow >= 25.04)
nextflow lint .
# PASS: 0 errors, 0 warnings

# nf-core pipeline repos only
nf-core pipelines lint
# PASS: failed == 0; warnings listed and triaged, not ignored

# Language server, if wired (nextflow-language-server / editor LSP)
# PASS: diagnostics == 0 on changed files
```

Prefer the repo's own lint entrypoint when one exists (e.g. a
`dev-ex-harness`/`nextflow-lint` wrapper, prek hook) — run that instead of
hand-rolling; same numeric bar applies.

## 3. On any failure: fix, restart from step 1

Re-run ALL checks after a fix, not just the failed one. Fixes regress other
checks.

Fix the code, not the check. Never weaken a lint rule or delete a test to go
green.

## 4. Done criteria (all must hold)

| Check                  | Criterion                             |
| ---------------------- | ------------------------------------- |
| nf-test                | failed == 0, passed == expected count |
| nextflow lint          | 0 errors, 0 warnings                  |
| nf-core pipelines lint | failed == 0 (pipeline repos)          |
| LSP diagnostics        | 0 on changed files (if wired)         |

Report each as `command → number`, e.g. `nf-test test → 27/27 passed, 0
failed`. No numbers, no done.
