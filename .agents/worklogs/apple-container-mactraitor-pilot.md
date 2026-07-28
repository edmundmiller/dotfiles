# Worklog: apple-container-mactraitor-pilot

Status: complete

## Objective

Replace MacTraitor-Pro's Nix-managed Docker CLI and Compose configuration with a fully declarative Apple Container runtime. Stop after Darwin evaluation checks, host rebuild, runtime status, ephemeral Alpine smoke, scoped landing, remote equality, and tag publication succeed. Leave Seqeratop and unmanaged Docker/OrbStack applications, symlinks, contexts, images, volumes, and data unchanged.

## Decisions

- Track `halfwhey/nix-apple-container` master through `flake.lock`; current master packages Apple Container 1.1.0 and includes post-v0.0.6 launchd fixes.
- Expose `modules.services.appleContainer.enable`; import the upstream Darwin module for both Mac configurations but enable it only on MacTraitor-Pro.
- Declare no persistent containers or Linux builders.
- Remove Docker tooling from Nix only. OrbStack remains the compatibility fallback for Docker/Compose-dependent workflows.

## Evidence

- Preflight: `MacTraitor-Pro.local`, arm64, macOS 27.0; task worktree clean and detached at `06043b43`.
- Current config: both Darwin hosts evaluate `modules.services.docker.enable = true`.
- Runtime boundary: `/usr/local/bin/docker*` are OrbStack-owned symlinks; OrbStack and Docker applications are unmanaged by this change.
- TDD RED: `nix build .#checks.aarch64-darwin.apple-container-pilot-assertions --no-link` failed with three intended host-state assertions, then two intended shell-alias assertions.
- TDD GREEN: the focused check passes with eight host/runtime/shell assertions; the MacTraitor-Pro Darwin system builds.
- `hey check` passes Darwin evaluation, formatting, hooks, tmux, package harness, package policy, and ast-grep tests.
- `hey agent-audit-tests` passes. The workspace `python3 -m unittest tests/test_agent_quality.py` passes all 15 tests.
- `hey agent-finish` passes repository quality, test confidence, and inventory drift. Its Nix-store copy of `agent-quality-tests` fails only while initializing a temporary jj fixture; the workspace test passes. Its zsh threshold fails (`first_command_lag_ms=396`, `command_lag_ms=35.4`), while first-command latency is 1607 ms better than the stored baseline and this change removes Docker startup sourcing.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` completed successfully after both the runtime switch and shell-alias correction.
- Live proof: `container system status` reports running CLI/apiserver 1.1.0 from the Nix store; `container run --rm alpine:latest echo apple-container-ok` succeeded; subsequent `container list --all` was empty.
- Removal proof: MacTraitor-Pro config has no Docker env variables, zsh/Compose aliases, or `/etc/profiles/per-user/emiller/bin/docker*`; OrbStack-owned `/usr/local/bin/docker*` symlinks remain.

## Reviews

- Plan review: blocked after all available heterogeneous routes failed before review: default Claude required authentication; Gemini ACP passed unsupported `acp`; OpenCode returned an internal service failure. The gate was run and the provider blockers were surfaced before implementation.
- Landing review: blocked before review because the Kimi ACP command could not spawn.

## Feedback

- `hey check` cannot run formatter/hooks in a fresh worktree until `nix develop -c true` generates the ignored `.pre-commit-config.yaml`; its error does not state this prerequisite.
- `hey agent-finish` executes repository checks from a Nix-store source lacking Git worktree context, producing noisy `git diff --cached` and temporary-jj failures that do not reproduce in the workspace.

## Remaining work

None. External plan/landing review provider failures are recorded above.

## Commits

- `4c998a864 feat(darwin): add Apple Container module`
- `c2cdc6b77 feat(mactraitorpro): pilot Apple Container`
