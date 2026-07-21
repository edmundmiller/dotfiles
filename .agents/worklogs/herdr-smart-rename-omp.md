# Worklog: herdr-smart-rename-omp

Status: active

## Objective

Package `iurysza/herdr-tab-smart-rename` under `packages/`, patch its model backend to call OMP in ephemeral tool-free mode, deploy it as a Nix-managed local Herdr plugin, start its worker automatically, and prove a live Pi/OMP tab can be named without a separate API key.

## Decisions

- Pin upstream v0.1.1 commit `2db0c157c4ff9e7b6b8a7e15ccdbc62c5bd7a109` and carry reviewable patches instead of vendoring mutable source.
- Use `omp -p --no-session --no-tools --no-skills --no-rules --no-extensions --no-title --model smol` so OMP owns provider selection and auth without exposing credentials.
- Keep the existing OpenAI-compatible backend available; select OMP by packaged default/config.
- Package production dependencies in Nix and remove the runtime install step from the local manifest.

## Evidence

- OMP backend smoke: exit 0, JSON-only stdout, progress on stderr.
- TDD provider RED: clean upstream plus the new provider behavior test failed with `Export named 'ProviderNamer' not found`; exit 1.
- Provider GREEN: `pkg-check herdr-tab-smart-rename` passed 24 tests plus TypeScript check; the OMP-only Nix package built successfully.
- TDD lifecycle RED: patched-provider upstream plus the manifest behavior test failed because `[[build]]` remained and lifecycle events were absent; exit 1.
- Lifecycle GREEN: both patches passed 24 upstream tests plus TypeScript check; the Nix package built with both lifecycle events and no runtime build step.
- TDD integration RED: the focused repository test failed because the managed package was absent from the Herdr module.
- Integration GREEN: 4 focused packaging tests passed; `ast-grep` and focused `hey check` passed, including Darwin evaluation and package policy.

## Reviews

- Plan gate attempted with `hey agent-review plan --active-model-family openai`; blocked by `RUNTIME: Authentication required` before review output.
- Landing review pending.

## Feedback

None.

## Remaining work

- Rebuild and complete live registry, provider, worker, and automatic-rename smoke tests.

## Commits

Pending.
