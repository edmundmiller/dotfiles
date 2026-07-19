# Worklog: lgtm-source-build

Status: complete

## Objective

Replace mutable LGTM.dmg packaging with a source-pinned Rust build. Stop when the fresh-source harness, Nix build, bundle smoke checks, `hey check`, Darwin rebuild, installed LGTM, and moshi-hook 0.2.51 all pass; then land the focused change upstream.

## Decisions

- Pin upstream commit `573ffe1fb626ff86c47e8b0e99f1179f1bdc8a03`, not the force-moved `latest` tag.
- Use `rustPlatform.buildRustPackage` and upstream's locked workspace.
- Install the release binary in the same minimal `.app` layout and plist used by upstream; omit DMG creation, signing, and speculative icons/resources.
- Add package-harness coverage for the locked Cargo workspace.
- Keep the live main checkout's unrelated commits and untracked workflow untouched.

## Evidence

- `hostname`: `MacTraitor-Pro.local`.
- `uname -a`: Darwin arm64, MacTraitor-Pro.
- Upstream `main` and force-moved `latest` both resolve to `573ffe1fb626ff86c47e8b0e99f1179f1bdc8a03` on 2026-07-18.
- `.github/workflows/release.yml` force-pushes `latest` and uploads `LGTM.dmg --clobber` after every main push.
- Upstream workspace contains six members; `crates/app` builds binary `lgtm` version 0.1.0.
- Upstream `LICENSE` is MIT; repository API reports SPDX `MIT`.
- Upstream source build requires Xcode Metal tools; package build must exercise that path on Mac.
- Initial source derivation failed exactly at GPUI's `metal` build tool lookup. The local patch enables GPUI's `runtime_shaders` feature, embedding shader source and compiling through the runtime Metal API.
- `nix build .#lgtm --no-link --print-out-paths` passed, including Nix `doCheck`; output: `/nix/store/mv8fmncxp1n5447g7vv5ld2w1g16m7dg-lgtm-0.1.0-unstable-2026-07-17`.
- Built app: arm64 Mach-O; plist lint passed with bundle version `573ffe1`; links `Metal.framework`.
- Direct store launch remained alive for five seconds, exercising runtime shader compilation and app startup.
- `pkg-check lgtm` passed from a fresh clone after applying `patches/runtime-shaders.patch`: 108 tests passed; three upstream LSP integration tests explicitly ignored because they require external binaries/checkouts.
- Harness isolates global/system Git configuration; without this, the host's mnemonic diff prefixes broke three upstream fixture assertions.
- `nix develop -c ast-grep scan packages/` passed.
- `hey check` passed all Darwin checks, package harness tests, package policy tests, and ast-grep tests. Its changed-file formatting/hook selectors were no-ops; `nixfmt` was run directly on the changed Nix file and commit hooks remain required.
- Pre-rebuild live state on 2026-07-18 already reports `moshi-hook version 0.2.51`; delegation context said 0.2.44, so final verification uses fresh runtime evidence.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` passed on MacTraitor-Pro; active system: `/nix/store/bw52q7jn74w9iml0a2qhm6gb8iw1m3ly-darwin-system-26.11.d5bd9cd`.
- Activated LGTM output: `/nix/store/3wf5jjy9ccqm6gzcdhl423alnlfsdpck-lgtm-0.1.0-unstable-2026-07-17`.
- Store and installed `/Applications/Nix Apps/LGTM.app` executables are byte-identical: SHA-256 `aa0c52c7e209e8619fd92da7edb704b9db6426092ccc44ca7367a9467a499717`.
- Installed arm64 app plist lint passed with bundle version `573ffe1`; installed app remained alive for a five-second launch smoke.
- Post-activation `moshi-hook --version`: `moshi-hook version 0.2.51`; launchd job is running with a live PID and has never exited.

## Reviews

- Plan gate attempted with `hey agent-review plan --active-model-family openai --worklog .agents/worklogs/lgtm-source-build.md`; ACP session creation exited 1 with `RUNTIME: Authentication required` before producing findings.
- Landing gate attempted with `hey agent-review landing --active-model-family openai --worklog .agents/worklogs/lgtm-source-build.md`; ACP session creation exited 1 with `RUNTIME: Authentication required` before producing findings.
- First finish gate caught `forbid-misplaced-patches`; moved the patch under `packages/lgtm/patches/`. It also required a supported worklog state; restored `active` until landing completes.
- Final `hey agent-audit-tests` and `hey agent-finish --worklog .agents/worklogs/lgtm-source-build.md` passed; visual-regression and zsh-performance were correctly not applicable.

## Feedback

Package harness commands inherit host Git configuration; Git fixture suites need explicit global/system config isolation.

## Remaining work

None.

## Commits

- `2a3ce7a8df` — `fix(lgtm): build reproducibly from Rust source`.
- This completion worklog commit.
