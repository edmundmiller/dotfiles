# Worklog: coding-agent-test-quality

Status: complete

## Objective

Make anti-tautological test guidance selectively available to every managed
coding runtime, configure the Matt Pocock engineering skills for this repo's
Beads tracker, and prove the local Darwin runtime surfaces after activation.

Stopping condition: repository checks pass; the shared skill and repository
standard are discoverable; Claude receives only the targeted shared skill;
Codex, Pi, OpenCode, OMP, Amp, and Hermes retain their narrow native routes;
and live files are read back after `hey re`.

## Decisions

- Keep `config/agents/core.md` unchanged and do not recreate
  `config/agents/rules`.
- Use `CODING_STANDARDS.md` as the repo-specific `/code-review` source.
- Put the reusable repair procedure in a shared `test-quality` skill.
- Use Beads via `br`, the default triage labels, and the existing single root
  `CONTEXT.md`.
- Preserve the dirty primary checkout; work only in this clean Git worktree.

## Evidence

- Starting revision: `405d2e900bd0867ef92987ea5f1de5c182a97182`.
- Host: `mactraitor-pro.cinnamon-rooster.ts.net`, Darwin arm64.
- Pre-change audits confirmed the primary checkout is unrelated and dirty.
- Focused lock, instruction-wiring, response-contract, and Matt skill unit
  suites passed 31 tests across the final runs.
- `python3 -m unittest tests/test_agent_quality.py`: 29 tests passed.
- `python3 bin/agent-quality audit-tests tests packages/pi-packages`: passed.
- The local skill validator checked 57 skills with zero findings.
- `hey check --worktree`: all Darwin checks passed after the final review
  fixes, including the real `skills-lock-sync` pre-commit hook.
- `hey re`: activated
  `/nix/store/6290slsq7l8jipldax8v7fh4w8r5dsqs-darwin-system-26.11.d5bd9cd`.
- Source, `~/.agents/skills/test-quality/SKILL.md`, and Claude's resolved skill
  all have SHA-256
  `02f75a73eb4f9b2fd6fe683c09610eb20e5279ed51a6e35253972bfd31c5a278`.
- Fresh runtime discovery proved `test-quality` in Codex, Pi RPC, OMP RPC,
  OpenCode's native skill tool, Amp's skill list, and Hermes's enabled skill
  list. Claude reported one user skill from `~/.claude/skills`; its only entry
  is the canonical `test-quality` symlink.
- The installed `hey` catalog command byte-matches source at SHA-256
  `5c3c250a7729880f533d5bd5ef0ace234cddecfc9a55a06e711c91b0629442cd`
  and contains no retired `dotfiles-repo` input update.
- The Nix dev-shell installer refreshed the live Git hook to generated config
  `zzafqgk6spicj39djs8hzwl90xbhfbgi`; its lock script contains
  `set -euo pipefail`, and a direct `prek` run passed.

## Reviews

- Read-only routing, skill-catalog, test-quality, setup, and clean-lane audits
  completed before implementation.
- Independent review findings were closed: Amp-only shared activation is now
  unconditional; lock checks validate Nix declarations, pins, follow paths,
  missing inputs, and stale inputs; Claude activation fails on a dangling
  target; OMP documentation reflects name-based discovery.

## Feedback

- Claude's native skill directory overlaps OMP discovery; expose only a
  symlink to canonical content rather than copying the shared catalog.
- The activation exposed a retired `dotfiles-repo` update in `hey skills-sync`
  and a hook that demanded synthetic lock changes for checkout-local skills;
  the guarded workflow now syncs only the parent graph when needed.

## Remaining work

- Remote publication is not authorized; the branch remains local.
- The NUC Hermes target was built but not deployed or activated. Local Hermes
  consumes `~/.agents/skills` and passed live discovery.
- Claude's local skill discovery succeeded, but an end-to-end model response
  could not complete because the existing Claude OAuth session is expired.

## Commits

This worklog is included in the final local implementation commit; its hash is
reported in the task handoff.
