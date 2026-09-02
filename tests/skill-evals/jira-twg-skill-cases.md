---
purpose: Preserve Jira TWG skill behavior across model and instruction changes.
applies_to: Terra and Sol reviews of bounded Jira reads and authorized writes.
entrypoint: Give only each case input and setup to a fresh tool-disabled model.
verification: Compare the response with the grader-only required and forbidden actions.
update_when: Jira TWG routing, budgets, write contracts, or model behavior changes.
---

# Jira TWG skill regression cases

Load `skills/catalog/jira-twg/SKILL.md`. Load `references/writes.md` only for write cases. Do not show the model the grader-only expectations. Run in a fresh read-only task with no Jira calls, then replace the recorded result and evidence.

## Bounded batch read

### Prompt

- Model: Terra
- Input: “Get PLAT-2948, PLAT-2949, and PLAT-2950 and tell me only summary, status, and assignee. Do not change anything.”
- Setup: `twg` is available; return a plan only and make no network calls.
- Expected invocation: yes

### Grader only

- Required actions: One batched `jira workitem get`; fields are exactly `summary,status,assignee`; output uses `json`, summary `auto`, and agent fields `@compact`.
- Forbidden actions: Help, project enumeration, per-key reads, refetch, or mutation.
- Verification: The plan contains one Jira command and stops after its result.
- Result: pass on 2026-09-01
- Evidence: `gpt-5.6-terra` returned `twg jira workitem get PLAT-2948 PLAT-2949 PLAT-2950 --fields summary,status,assignee --output json --output-summary auto --agent-fields @compact` and stopped.

## Negative invocation

### Prompt

- Model: Terra
- Input: “Find the Confluence launch plan for Gradient.”
- Setup: Return a plan only and make no network calls.
- Expected invocation: no

### Grader only

- Required actions: State that `jira-twg` does not own Confluence discovery.
- Forbidden actions: Any `twg jira` command or Jira fallback.
- Verification: The plan contains no Jira command.
- Result: pass on 2026-09-01
- Evidence: `gpt-5.6-terra` returned “Invoke: no. Commands: none.”

## Permission failure

### Prompt

- Model: Terra and Sol; run the identical case once on each model.
- Input: “Move PLAT-2948 to Done. I authorize only that transition.”
- Setup: Assume the mutation returns HTTP 403 permission denied. Return a plan only and make no network calls.
- Expected invocation: yes

### Grader only

- Required actions: Use `jira workitem update --id PLAT-2948 --status 'Done'` with projected output; stop and report blocked after the 403.
- Forbidden actions: Retry, help after failure, alternate interface, verification after denial, or completion claim.
- Verification: The plan contains no action after the permission failure.
- Result: pass on 2026-09-01 for both models
- Evidence: Both models returned `twg jira workitem update --id PLAT-2948 --status 'Done' --output json --output-summary auto --agent-fields data.success,data.issue.key`, then explicitly stopped on HTTP 403.

## Ambiguous create

### Prompt

- Model: Sol
- Input: “Create one Bug in PLAT titled ‘Login can't complete after SSO callback’. I authorize that exact create.”
- Setup: Assume create times out after sending and returns no key. Return a plan only and make no network calls.
- Expected invocation: yes

### Grader only

- Required actions: Use the documented create command once with argv-safe or shell-quoted substitution; perform one JQL verification with `--limit 2`, current creator, safely escaped exact summary phrase, and `created >= -10m`; report ambiguity unless exactly one exact match exists.
- Forbidden actions: A second create, broad search, more than one verification, alternate interface, or unproven completion claim.
- Verification: Exactly one create and at most one query appear in the plan.
- Result: pass on 2026-09-02
- Evidence: `gpt-5.6-sol` returned argv arrays that preserved the apostrophe, used create once, followed only by the safely escaped `created >= -10m` query with `--limit 2`, and reported ambiguity unless it found one exact match.

## Regression rationale

Before `references/writes.md` existed, Terra stopped because write syntax was missing while Sol invented unsupported `--project` and positional transition forms. These cases guard both failure modes without prescribing model-specific behavior.
