# Worklog: retire-legacy-agent-rules

Status: blocked

## Objective

Retire `config/agents/rules` after moving Codex, Claude, Pi, and OpenCode to the
thin core, while preserving OMP's selective TTSR layer. Stop only after focused
tests, the repository gate, Darwin activation, and independent live readback of
each runtime instruction surface, or after recording an exact harness blocker.

## Decisions

- Start from current `origin/main` in a dedicated clean Git worktree because the
  primary checkout is far behind and contains unrelated work.
- Delete or route existing procedures instead of mechanically turning every
  legacy rule into a skill.
- Install the same bounded core at Claude `CLAUDE.md`, Codex/OMP/Pi
  `AGENTS.md`, and OpenCode V2's global `AGENTS.md`; OpenCode's retired
  `instructions` glob is not an active V2 discovery surface.
- Keep OMP's four native TTSR rules because they are intentional conditional
  routing, not always-on startup context.
- Move the only unique reusable residue to existing scoped interfaces: the
  expected-failure regression sequence belongs in `AGENT_WORKFLOW.md`, while
  routine validation's no-manual-Prek rule belongs in `docs/agent-guardrails.md`.
  No new global skill is justified.
- Do not absorb the separate Hermes Python/libffi/tokenizers repair into this
  agent-instruction migration. The normal Darwin candidate build identifies it
  as the exact activation blocker, and importing it would widen this task into
  an unrelated runtime-package change.

## Evidence

- Host before Darwin work: `MacTraitor-Pro.local`, Darwin 27.0.0, arm64.
- Starting revision: `5839233b6f1e9c45d1dc41b58f3da1b149682afe`.
- Primary checkout dirt was inspected and left untouched.
- `config/agents/core.md` is 217 words, under its 220-word budget.
- The focused six-file agent suite passed 63 tests.
- Skill-quality validation passed for the changed project-local Oracle skill;
  the generated quality inventory and `git diff --check` are clean.
- `omp ttsr list --json` independently exposed all four managed native rules.
- `modules/agents/pi/test-settings-json.sh` reproduced the inherited
  `nixpkgs-overlays` recursion on `origin/main`; its fallback now disables
  implicit overlays and passes directly.
- OMP's registry check now uses the same patched OMP 18 package Darwin deploys.
  The source config uses canonical `compaction.methodOrder: [remote, soft]` and
  `features.unexpectedStopDetection: smart`; isolated validation passes 100
  keys without changing their migrated semantics.
- The earlier `flake.lock` pin normalization landed independently upstream and
  is not part of this task commit.
- `./bin/hey check --worktree` passes Darwin evaluation, formatting,
  pre-commit hooks, tmux, package harness/policy, DJI Mic Mini, and ast-grep
  checks.
- `hey agent-audit-tests` passes its test-confidence audit.
- Nix evaluation realizes the intended Claude, Codex, OMP, Pi, and OpenCode
  instruction artifacts byte-for-byte from the 217-word core. All five have
  SHA-256 `a04160efd7776299d1fc902a55fe80ac4b53e2f117734c1f3147d5e383343338`.
- `hey re build` does not produce a Darwin system result. It reaches the
  unchanged Hermes dependency chain and aborts in
  `/nix/store/bdkszz732586ki783gfqhxk2byf6ckpn-python3.12-h5py-3.15.1.drv`
  during `h5py.tests.test_h5z.test_register_filter` with exit code 134. No
  activation was attempted.
- An independent derivation-tree comparison proves current `origin/main` and
  this task branch both contain that exact h5py derivation. The activation
  failure is not introduced by the agent-rule cleanup.
- Independent live readback therefore shows the previous Home Manager
  generation: Claude and Pi still expose the legacy 2,863-word bundle; Codex
  and OMP expose the older 212-word core; OpenCode V2 has no `AGENTS.md`, still
  declares the numbered-rule `instructions` glob, and retains the old rule
  symlinks. OMP still exposes the four intended native TTSR rules.

## Reviews

- Runtime-source inspection confirmed Claude and Pi accept the bounded core
  directly; installed OpenCode V2 code discovers its global `AGENTS.md` and
  ignores the former `instructions` glob.
- Rule inventory found no procedure that warranted a new global skill after the
  two scoped workflow/guardrail moves.
- The independent stale-doc review identified old OpenCode V1 ownership claims;
  the active OpenCode guides now describe the canonical V2 root and Herdr's
  compatibility alias.
- Release review found that the alias itself depended on Herdr and that the
  autonomous-loop skill still named shared rules. The OpenCode module now owns
  the alias in standalone mode, and the skill routes learning only to scoped
  instructions, existing skills, prompts, docs, or deterministic checks.
- A fresh gate exposed an intermittent Bash heredoc deadlock in the Pi settings
  hook. The same validator now runs from a normal Python file; both the Nix
  Python hook environment and the standalone fallback pass without recursion or
  a heredoc writer.
- A final independent source audit found no tracked file or active source
  consumer under `config/agents/rules`; remaining references are historical
  documentation or negative regression assertions.

## Feedback

The pre-commit environment initially retained an older generated hook command,
and the inline Pi validator could deadlock under that hook. Re-entering the Nix
development shell refreshed the managed hook, and moving the validator to a
normal Python file made the guarded path deterministic.

## Remaining work

- Land the separately reviewed Hermes Darwin Python/libffi/tokenizers repair on
  current `origin/main`, then rerun the normal `hey re` build/activation gate.
- After a successful activation, independently prove that all five runtime
  instruction files hash to the shared core, OpenCode's legacy rules/glob are
  gone, and OMP still exposes its four native rules.
- Publication was separately authorized by an explicit `/done`. Use the clean
  integration lane so the primary checkout's unrelated dirt remains untouched.

## Commits

- `refactor(agents): retire legacy startup rules`
