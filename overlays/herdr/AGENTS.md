# Herdr overlay

Overlay `llm-agents.herdr`; consumers use `pkgs.my.herdr` / `.#herdr`, not a
top-level `pkgs.herdr` alias. Ordered source patches live in `patches/` and
`default.nix`. Dotfiles-specific plugin behavior belongs in
`config/herdr/plugins/` when the plugin API supports it.

Renovate owns the rev, source hash, and matching harness ref. The repair workflow
runs the trusted base's `pkg-check herdr` against the PR snapshot, invoking Flue
only on deterministic failure. PR code runs in no-secret containers; the agent
can change only patches. The trusted importer regenerates manifests, not agent
source pins. Required GitHub checks remain merge authority.

Use `pkg-check herdr` and the `nix-package-patching` skill for source validation.
Outside Nix on macOS, vendored libghostty-vt's Zig SDK link can fail before Cargo
tests run; use the Nix build environment for runtime test evidence. Successful
patch application alone does not establish that the patched binary works.
