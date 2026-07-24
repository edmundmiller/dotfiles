# Worklog: nuc-llm-agents-update

Status: active

## Objective

Update the `llm-agents` flake input if its pinned revision is behind upstream, deploy the resulting current configuration to NUC, and prove Codex and OMP start there. Stop when NUC runs the deployed generation and both CLI smoke checks pass.

## Decisions

- Deploy from a clean worktree based on `origin/main`; preserve the user's dirty, diverged worktree.
- Compare the input pin directly with `numtide/llm-agents.nix` upstream before treating either CLI as current.

- Retire local patch `0003-fix-bundled-extension-imports`: OMP v17.1.0 already contains its virtual-specifier resolver and extension-load notification implementation.
- Keep portable harness coverage limited to fresh patch application plus the Herdr/Hunk test; run the Rust test in Nix's package environment on NUC.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin arm64.
- Updated `llm-agents` from `0081aa9366465668e321372e4b2047bf01116a97` (2026-07-19) to upstream `264604cc0580e87d34a10b82334cf52f8139053f` (2026-07-24), with its declared `bun2nix` and `nixpkgs` inputs.
- Removed obsolete OMP patch `0003-fix-bundled-extension-imports.patch` and refreshed the OMP cargo vendor hash to `sha256-n8bK/ZdlBE2rfOJkn4ELjpVfDkwT1gzCSydNKjVmJHU=`.
- `hey nuc-wt build` re-synced and successfully built the final worktree as `/nix/store/mld1dc8iz2gcdy21qkm9gll0s40gn2nv-nixos-system-nuc-26.11.20260714.18b9261`.
- `nix develop -c pkg-check omp` fresh-cloned OMP v17.1.0, applied both retained patches, and passed all 10 tests in `herdr-hunk-protocol.test.ts`.
- On NUC, the exact overridden Nix package ran `cargo test -p pi-natives`: 178 passed, including `ast::tests::nextflow_process_pattern_matches_inferred_nf_file`.

## Reviews

- Landing review attempted after focused tests; blocked before findings: `RUNTIME: Authentication required`.
- Plan review attempted with `agent-quality`; blocked before findings: `RUNTIME: Authentication required`.

## Feedback

- `hey agent-start` dispatches incorrectly; `python3 bin/agent-quality start` produced the required run receipt.
- Raw `cargo test -p pi-natives` is not a portable harness check on this Darwin host: it fails even with `RUSTC_BOOTSTRAP=1` while resolving `const_random_macro`; the canonical Nix build sets the complete Rust environment and already compiled the patched package.

## Remaining work

Land the reviewed change, dry-activate, deploy, and smoke-test NUC.

## Commits

Pending.
