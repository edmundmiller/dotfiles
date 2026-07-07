# Hunk overlay instructions

This directory patches the upstream `modem-dev/hunk` input used by `modules/shell/git/default.nix`.

When changing any Hunk patch:

1. Apply the checked-in patch stack to a fresh upstream `modem-dev/hunk` checkout at the pinned tag.
2. Make the source change there, then regenerate the checked-in patch from that checkout.
3. Fresh-apply the regenerated patch to a clean upstream checkout.
4. Run Hunk's targeted validation from that fresh checkout:
   - `bun run typecheck`
   - targeted `bun test` for the edited area
5. If adding a provider/source, include a test that exercises the exact provider marker/path, not just the shared abstraction.

For last-agent sources, test the provider marker directly. Example: adding Codex means a test must create `hunk/last-codex-turn.json` and assert `last-agent-turn` resolves to the Codex patch/label.
