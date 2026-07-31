# Worklog: buzz-flue2-cutover

Status: blocked

## Objective

Move MillDocs Buzz ownership from the NUC direct responder and beta Flue Worker to a dedicated Flue 2 Worker while retaining the existing NUC Linear coding queue. Stop after source, deployment, and one fresh end-to-end Buzz verification agree.

## Decisions

- MillDocs owns the standalone Worker; dotfiles owns only NUC service and callback wiring.
- Disable `buzz-mill-docs-codex.service`; keep `mill-docs-coding-agent.timer`.
- Rehydrate conversation context from verified relay events instead of beta Durable Object state.
- Use a cutover watermark plus an app-owned event-claim Durable Object; Flue 2.0.0 does not expose submission idempotency keys.

## Evidence

- Initial checkout clean on `codex/feedback-fix-loop`.
- Host: `MacTraitor-Pro.local`, Darwin arm64; NUC checks and deployment must run through `hey nuc-wt` / `hey nuc`.
- `uvx pytest -q tests/test_mill_docs_coding_agent.py`: 5 passed.
- `hey nuc-wt build`: built `/nix/store/bsza5vfzr9y72d3x1j44q5kg0xzjisgq-nixos-system-nuc-26.11.20260714.18b9261`.
- `hey agent-audit-tests ...`: `PASS test-confidence`.

## Reviews

- Plan: Claude review failed authentication; required Gemini retry also failed authentication. Implementation proceeded from the accepted user plan and local evidence.
- Landing: Claude review failed authentication; required Gemini retry also failed authentication. Independent standards/spec reviews reached fixed point with no actionable findings.

## Feedback

None.

## Remaining work

- Clean or explicitly preserve the dirty MillDocs `main` checkout so the feature commit can land without touching unrelated vault edits.
- After landing: deploy old-ownership removal, deploy NUC wiring, set the exact cutover watermark, enable the new poller, update the hosted Buzz workflow, and run live normal/fix acceptance.

## Commits

- `834701648` — NUC Buzz ownership and callback wiring.
- MillDocs companion commit: `520bb21`.
