---
name: verify-loop
description: >
  Define done quantitatively before claiming done: find the repo's canonical
  checks, run what CI runs locally at the same versions, check docs still match
  code, restart from step 1 on any failure. Use before commit, handoff, or any
  "done" claim on a nontrivial change.
---

# Verify Loop

Not Claude's built-in `/verify` (drive the change end-to-end); this is about
finding and ENCODING the repo's quantitative checks and running them to zero.

## 1. Define done numerically

Before heavy work, list the checks that gate this repo and the numbers that
mean pass: tests N/N, lint errors 0, typecheck errors 0, build exit 0. If you
can't name the numbers, you can't claim done.

## 2. CI parity: run what CI runs, locally, same versions

Find the canonical entrypoint — in order of preference:

1. Repo hook config: `prek.toml`, `.pre-commit-config.yaml` → `uvx prek run --all-files`
2. `.github/workflows/*.yml` — copy the exact commands and pinned versions
3. `Justfile` / `Makefile` / repo harness script (e.g. `tools/harness.py`)

Run the exact CI-shape command, pins included. Repo-canonical examples:

```bash
# gradient-v2 frontend: pinned version + vendored config, byte-for-byte CI shape
pnpm dlx oxlint@1.68.0 -c dev-ex-harness/checks/oxlint/.oxlintrc.json dashboard design-system

# Gradient mergeability: weave preview is the real check;
# GitHub mergeStateStatus alone is misleading
weave preview
```

An unpinned local run passing means nothing about CI.

## 3. Docs-match-code check

```bash
git diff --name-only origin/main...HEAD -- 'docs/**' '**/AGENTS.md' '**/contracts/**' '.agents/skills/**'
```

For each changed behavior/contract/ownership: nearby docs updated, confirmed
still matching, or follow-up issue filed. State which.

## 4. Any failure → fix → restart from step 1

Re-run the FULL check list after every fix, not just the failed check. Fixes
regress other checks; the loop only exits when one clean pass covers
everything.

## 5. If a check matters, encode it

A check that lives in your head or a PR comment dies. Repeated finding →
smallest repo-owned enforcement: hook, script, CI job, or lint rule near the
code it protects. Social policy is not verification.

## Report

One line per check: `exact command → numeric result`. Skipped checks named
with the missing tool/config. No numbers, no done.
