# Hunk overlay

The Hunk input tag and harness ref move together under Renovate, including the
lockfile. The repair workflow runs trusted-base `pkg-check hunk` against the PR
snapshot; Flue runs only on failure in no-secret containers. Its edits are
patch-only; the trusted importer regenerates the harness list without accepting
agent pins/lockfiles. Required checks remain merge authority.

Regenerate patches from the pinned upstream tree. The `nix-package-patching`
skill covers that workflow. Provider additions need their
actual marker contract covered: e.g. `hunk/last-codex-turn.json` resolves through
`last-agent-turn` to the Codex patch/label, not just a shared abstraction.

Run `pkg-check hunk` for every tag, lock, or patch change and run `hey check` on
`overlays/hunk` for repository consumers. The harness runs typechecking and
targeted Bun tests; require a test of the provider-specific marker path.
