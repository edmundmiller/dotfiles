# Worklog: herdr-vercel-agent-selection-mtp

Status: complete

## Objective

Make Codex, OMP, and a pinned OpenCode V2 beta explicitly selectable when starting a new Vercel Sandbox from Herdr on MacTraitor Pro, with Codex remaining the default.

## Decisions

- Package the upstream Vercel Sandbox plugin at a fixed commit and carry the smallest local action-selection patch.
- Keep Codex on the lifecycle-verified built-in adapter.
- Treat OMP and OpenCode V2 as explicit unverified custom profiles, pinned to exact package versions and authenticated inside each persistent Sandbox.
- Preserve unrelated untracked worklog and Beads files.

## Evidence

- Preflight: MacTraitor Pro, Darwin arm64; repository main matched origin/main before edits.
- Upstream plugin 0.6.0 exposes only one static `start-agent` action and reads a single configured `agentKind`.
- Current exact releases: `@oh-my-pi/pi-coding-agent@17.2.12`; `opencode-ai@beta` resolves to `0.0.0-beta-202608091410` (there is no stable 2.x release).
- Red/green: the focused packaging test failed before implementation, then all 10 packaging tests passed.
- `pkg-check herdr-vercel-sandbox-plugin` applied the patch to a fresh upstream checkout and passed all 87 upstream tests plus adapter verification.
- The patched Nix package, focused Herdr config check, and `hey check` passed; `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` completed.
- Live Herdr proof: config reload applied without diagnostics; the local Nix plugin exposes `start-codex`, `start-omp`, and `start-opencode-v2`; all three managed shortcuts are present.
- The live plugin parser resolved Codex `0.146.0` as lifecycle-verified, OMP `17.2.12` as an unverified custom profile, and OpenCode V2 beta `0.0.0-beta-202608091410` as an unverified custom profile.
- npm metadata confirms the OpenCode V2 beta supports Linux arm64/x64, OMP requires Bun 1.3.14+, and the pinned Bun package carries Linux arm64/x64 binaries.

## Reviews

None requested.

## Feedback

The upstream real-PTY deletion test is unreliable inside the isolated Nix build, so the derivation runs focused action/docs tests. The required fresh-checkout package harness ran the complete upstream suite on the host and passed its real-PTY test.

## Remaining work

- Complete Vercel CLI login and link an intended worktree before the first remote launch. OMP and OpenCode V2 remain explicitly labeled unverified until their live Vercel Sandbox lifecycle is exercised.

## Commits

- `feat(herdr): add selectable Vercel agents`
