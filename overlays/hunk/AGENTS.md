---
purpose: Define Hunk overlay patch and source-pin maintenance.
applies_to: Changes under overlays/hunk/ or the Hunk flake input.
entrypoint: Read package-harness.json and the target patch.
verification: Run pkg-check hunk and hey check.
update_when: Hunk source pins, patch stack, or package checks change.
---

# Hunk overlay instructions

This directory patches the upstream `modem-dev/hunk` input used by `modules/shell/git/default.nix`.

## Source pins

`flake.nix` Hunk input tag and `package-harness.json` `ref` must match. Renovate
owns both pins, regenerates `flake.lock`, and labels the PR `flue-review`; never
bump one pin alone.

`.github/workflows/renovate-patch-repair.yml` runs the trusted base revision's
`pkg-check hunk` against the PR snapshot, invokes Flue only when that
deterministic check fails, then enables platform automerge. All PR code executes
in no-secret containers. The isolated agent may change only `patches/*.patch`;
the trusted importer regenerates the harness patch list without accepting source
pins or lockfiles from the agent. Required GitHub checks remain the final merge
authority. The workflow needs `OPENROUTER_API_KEY` and a dedicated
`RENOVATE_TOKEN` repository secret plus a `RENOVATE_LOGIN` repository variable
matching the token owner.

When changing any Hunk patch:

1. Apply the checked-in patch stack to a fresh upstream `modem-dev/hunk` checkout at the pinned tag.
2. Make the source change there, then regenerate the checked-in patch from that checkout.
3. Fresh-apply the regenerated patch to a clean upstream checkout.
4. Run Hunk's targeted validation from that fresh checkout:
   - `bun run typecheck`
   - targeted `bun test` for the edited area
5. If adding a provider/source, include a test that exercises the exact provider marker/path, not just the shared abstraction.

For last-agent sources, test the provider marker directly. Example: adding Codex means a test must create `hunk/last-codex-turn.json` and assert `last-agent-turn` resolves to the Codex patch/label.
