---
purpose: Define Herdr overlay ownership, patch policy, and validation.
applies_to: Changes under overlays/herdr/.
entrypoint: Read default.nix and the relevant patch.
verification: Run pkg-check herdr, build .#herdr, and smoke-test the binary.
update_when: The Herdr pin, overlay API, patch stack, or test workflow changes.
---

# Herdr Overlay

This overlay owns the repo-local Herdr package customization.

## Canonical package path

Consumers should use `pkgs.my.herdr`.

Do not add or consume top-level `pkgs.herdr`. The flake package output `.#herdr`
comes from the overlaid `pkgs.llm-agents.herdr`, and the default overlay exposes
package outputs under `pkgs.my.*` for modules.

## Why this overlays `llm-agents.herdr`

Herdr originates from the `llm-agents` input package set. This overlay replaces
that nested package so callers that intentionally inspect `pkgs.llm-agents.herdr`
see the dotfiles-patched build, while normal dotfiles modules still use the
clearer `pkgs.my.herdr` Interface.

## Patch layout

Keep source changes in `patches/*.patch`, applied in order from
`default.nix`. Prefer small single-purpose patches. If adding command behavior,
keep the command implementation and its CLI wiring together unless there is a
shared implementation Module that clearly earns its locality.

## Renovate releases

Renovate owns the Herdr `rev`, source hash, and matching
`package-harness.json` `ref`. It labels release PRs `flue-review` but leaves
automerge disabled. `.github/workflows/renovate-patch-repair.yml` runs the
trusted base revision's `pkg-check herdr` against the PR snapshot, invokes Flue
only when that deterministic check fails, then enables platform automerge. All
PR code executes in no-secret containers. The isolated agent may change only
`patches/*.patch`; the trusted importer regenerates both patch manifests without
accepting source pins from the agent. Required GitHub checks remain the final
merge authority. The workflow needs `OPENROUTER_API_KEY` and a dedicated
`RENOVATE_TOKEN` repository secret plus a `RENOVATE_LOGIN` repository variable
matching the token owner.

## Testing patched Herdr sources

To test a patch against the pinned upstream source, materialize the patched tree
outside the dotfiles repo and run Cargo there. Example for detector/pane tests:

```sh
set -euo pipefail
workdir=$(mktemp -d)
repo=$(git rev-parse --show-toplevel)
git clone https://github.com/ogulcancelik/herdr "$workdir/herdr"
cd "$workdir/herdr"
git checkout "$(sed -nE 's/^[[:space:]]*rev = "([^"]+)";/\1/p' "$repo/overlays/herdr/default.nix")"
git apply "$repo"/overlays/herdr/patches/*.patch
cargo test \
  detect::tests::hermes \
  pane::tests::screen_chrome_overrides_codex_backend_to_hermes \
  pane::tests::screen_chrome_does_not_override_pi_process_agent
```

For plugin migrations, prefer local Herdr plugins under `config/herdr/plugins/`
over dotfiles-only patches to Herdr CLI/config behavior.

On macOS outside the Nix build, `cargo test` may fail before tests run while the
vendored `libghostty-vt` Zig build links against the SDK. In that case, at least
verify patch application with `git apply --check .../patches/*.patch`, or run the
tests through the Nix Herdr build environment.
