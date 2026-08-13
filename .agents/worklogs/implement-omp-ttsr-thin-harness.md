# Worklog: implement-omp-ttsr-thin-harness

Status: complete

## Objective

Implement ADR 0010's OMP-first pilot. OMP must load a shared core of at most
250 words instead of the legacy concatenated rule bundle, local TTSR rules must
have deterministic positive and negative fixtures, and procedural guidance must
remain routed through skills and repository documents. Stop before changing
Codex or Pi instruction wiring, activating a host, or publishing changes.

## Decisions

- Use `config/agents/core.md` as the semantic shared-core source, initially
  consumed only by OMP.
- Exercise TTSR through the installed public `omp ttsr test --rule` interface.
- Keep the `git commit` overlap between commit style and backend safety when
  both reminders are relevant; eliminate the unrelated `rg jj README.md`
  false positive.
- Preserve unrelated edits in shared rules 15 and 16.

## Evidence

- ADR 0010 and current OMP rule/module wiring inspected.
- Live runtime advanced from the ADR baseline to `omp/17.2.15`; `ttsr test`
  exercises source rules without requiring activation.
- RED: OMP core source was absent; quoted `git commit`, `gh pr create`, `jj`,
  and `HERDR_ENV` searches triggered rules; CI guidance was always-on.
- GREEN: 33 named positive/negative scenarios pass through the public TTSR CLI,
  and the explicit TTSR configuration loads through `omp config list`.
- `omp ttsr scan` skips the command rules as `noRelevantRules`, confirming it
  is not a valid proof surface for `tool:bash`; named fixtures are the gate.
- `python3 -m unittest tests/test_agent_instruction_wiring.py
tests/test_omp_ttsr_rules.py tests/test_agent_rules.py
tests/test_agent_response_contract.py`: 19 tests passed.
- All four focused OMP configuration scripts passed, including the exact TTSR
  values in `test-config-yml.sh`.
- `nix build path:$PWD#checks.aarch64-darwin.omp-thin-harness-tests --no-link`
  passed against the pinned OMP package.
- Generated OMP `AGENTS.md` for both Darwin configurations matches
  `config/agents/core.md` byte-for-byte, while Codex and Pi retain the legacy
  rule bundle.
- `python3 bin/agent-quality inventory --check`, `git diff --check`, and
  `./bin/hey agent-audit-tests` passed.
- `./bin/hey check --worktree` passed all Darwin, formatting, pre-commit,
  tmux, package-harness, package-policy, and ast-grep checks.

## Reviews

Plan gate: ADR 0010 is the user-approved plan. Cross-model review was not
requested and is therefore not a gate.

## Feedback

TTSR scan is useful for edit/write rules but intentionally cannot evaluate
`tool:bash` rules against repository files. The ADR now distinguishes those
verification surfaces instead of treating a skipped scan as a pass.

## Remaining work

None for source implementation. Host activation and extending the thin core to
Codex or Pi remain explicit follow-up decisions.

## Commits

Recorded in Git history during closeout.
