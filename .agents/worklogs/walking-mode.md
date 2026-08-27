# Worklog: walking-mode

Status: complete

## Objective

Add a model-invoked, Codex-only walking mode that preserves full task state
while reducing spoken updates. Stop when routing, deterministic validation,
three voice-behavior cases, semantic review, and a local hooked commit pass.

## Decisions

- Use one `SKILL.md` under the explicit local Codex source. There is no simpler
  repository prompt or mode mechanism, and no reference or script has earned a
  second file.
- Keep model invocation because natural hands-free phrases must activate the
  behavior without the user remembering a command. Limit its description's
  context load to Codex with `meta.targets = [ "codex" ]`.
- Keep the detailed contract in the skill only. This worklog records design and
  evaluation evidence without restating the operating rules.
- Do not activate the Nix configuration; use read-only evaluation and narrow
  bundle builds for routing proof.

## Evidence

- Checkout ownership: `/Users/emiller/.codex/worktrees/84c9/dotfiles`; detached
  worktree at `17825e142`, clean before editing, with no rebase, merge, or index
  lock active.
- Behavioral cases to run on Terra and Sol:
  1. Common: “I’m walking the dog and not at the computer while three
     background tasks run. Task A was dispatched, task B is running 47 of 63
     tests, and task C is waiting on an API. Keep going and tell me only what I
     need to do.” Expected: invoke from context and acknowledge briefly without
     process detail.
  2. Negative: “Rewrite this release note concisely for the changelog.”
     Expected: no invocation or walking-mode persistence.
  3. Decision: “Walking mode. One task finished at commit abc123, one is still
     running 47 tests, and the production deployment is waiting for my
     approval. Update me.” Expected: one approval question, minimal context,
     and a bundled recap only because an update was requested.
- `skill-quality` targeted gate: `checked=1`, `findings=[]`; repository skill
  gate: `checked=56`, `findings=[]`.
- Read-only Nix evaluation returned `meta.targets = [ "codex" ]`. Narrow bundle
  builds/readback found `walking-mode` in Codex and absent from agents, Pi,
  OpenCode, and Hermes bundles.
- Terra and Sol both invoked on the implicit walking/not-at-computer case,
  withheld dispatch/test/API details, and spoke one sentence. Both rejected
  invocation on the ordinary concise-writing case.
- The first decision-case pass compressed correctly but phrased approval as a
  directive. The skill now says to ask one question when a response is needed;
  fresh Terra and Sol reruns each asked exactly one deployment-approval
  question and held the commit ID and test count.
- Final containment readback found PIDs 72743–72745 absent,
  `/run/current-system` unchanged at
  `/nix/store/1srai9g045vp5qgkxk15qk0wgg85k6xj-darwin-system-26.11.d5bd9cd`,
  system profile generation still 1686, and
  `~/.codex/skills/walking-mode` absent. No activation occurred.

## Reviews

Terra and Sol behavioral cases pass after the one-question wording repair.
`sem diff --staged` reports only this worklog, the skill, and the targeted Nix
routing; the detailed staged patch matches the requested scope.

## Feedback

`hey skills-sync` unexpectedly entered `darwin-rebuild switch`; its name does
not expose that activation boundary. The user-owned parent was stopped before
activation output; the coordinator terminated the remaining root-owned build
processes, and unchanged-generation readback proved containment. Future
no-activation skill work needs a narrow sync path or an explicit warning from
`hey`.

## Remaining work

None.

## Commits

- This commit — add the Codex-only walking mode, routing, and evaluation record.
