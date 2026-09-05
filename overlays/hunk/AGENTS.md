# Hunk overlay

The Hunk input tag and harness ref move together under Renovate, including the
lockfile. The repair workflow runs trusted-base `pkg-check hunk` against the PR
snapshot; Flue runs only on failure in no-secret containers. Its edits are
patch-only; the trusted importer regenerates the harness list without accepting
agent pins/lockfiles. Required checks remain merge authority.

Regenerate patches from the pinned upstream tree and validate fresh application
with `pkg-check hunk` (typecheck and targeted Bun tests). The
`nix-package-patching` skill covers that workflow. Provider additions need their
actual marker contract covered: e.g. `hunk/last-codex-turn.json` resolves through
`last-agent-turn` to the Codex patch/label, not just a shared abstraction.
