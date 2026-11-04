# Worklog: pi-1-upgrade

Status: blocked

## Objective

Upgrade the Nix-managed Pi to 1.0.0, use native MCP and codemode, and verify Herdr integration. Stop after focused runtime checks and publication; host activation must not include unrelated local NUC changes.

## Decisions

- Keep the shared llm-agents input pinned. Override Pi only to avoid upgrading unrelated agents.
- Native MCP replaces pi-mcp-adapter, which otherwise disables native MCP.
- Preserve existing model choices and credentials. Do not add paid services or grants.
- Reuse the pinned upstream package and its toolchain. Calling its package definition with the old package set fails because `formatelf` is missing; the newer Bun/compiler and codemode worker must stay together.
- Upgrade pi-herdr to 0.4.0 only with Herdr 0.7.5+. Keep plugin 0.2.5 for the patched Darwin Herdr 0.7.4 until its three remaining behavior patches are ported.

## Evidence

- Installed Pi reports 0.84.4; installed Herdr reports 0.9.1.
- Pi v1.0.0 release and native MCP docs verified against earendil-works/pi.
- Upstream pi-herdr 0.4.0 uses typebox and current tool APIs.
- Run receipt: /home/emiller/.local/state/dotfiles-agent-runs/a6c029f1d879/20261002T034439Z-c906a1a5544d.json
- `nix build .#pi --out-link .amp/in/pi-upgrade/result` succeeded; executable reports 1.0.0. Darwin package version evaluates to 1.0.0; no Darwin build was run.
- Settings schema validation passed using `uv run --with jsonschema`; runtime-wrapper check and `hey help` passed.
- NUC Home Manager settings evaluated through `/run/wrappers/bin/sudo nix-private-github`; no legacy MCP packages remain.
- Native `pi mcp list --json` connected to GitHub with 46 tools. Linear needs OAuth sign-in; no credential grant was attempted.
- RPC startup with the generated files returned successful get_state/get_commands responses and selected openai-codex/gpt-5.6-sol with existing credentials.
- Runtime probe found codemode, exec_command, apply_patch, all three pi-herdr 0.4.0 tools, and 46 MCP tools together. No model request or tool mutation was run.
- Nix assertions passed for the Herdr 0.7.4/0.7.5 boundary, Herdr-disabled settings, and legacy adapter filtering in string/object forms.
- Existing runtime has a stale Nix-managed lazy-agent-browser extension that conflicts with the current browser package. The generated Home Manager files omit it and load successfully.
- `hey agent-audit-tests modules/agents/pi`, eight package-policy tests, and native MCP enabled/disabled Nix assertions passed. All pre-commit and commit-message hooks passed.
- Full `hey agent-finish` was terminated by SIGTERM during dependency compilation. No full-gate result was produced; this is not a pass. Artifacts are under `.amp/in/artifacts/pi-1-upgrade/`.
- The local commit amendment succeeded, but its br-sync-merge post-rewrite hook conflicted with pre-existing Beads changes. Prek rolled back the hook edits and restored the unrelated working-tree changes. Do not treat the post-rewrite hook as passed.

## Reviews

Plan gate could not run: installed hey lacked agent-review, then repo-local hey found bin/agent-quality but acpx was unavailable. This is not a review pass. Landing review has the same missing prerequisite.

## Feedback

The fff command is unavailable; used scoped searches and Finder. The settings test's Nix fallback assumes a nixpkgs channel; uv supplied jsonschema without changing that unrelated test. sudo on PATH is not setuid; the NixOS wrapper works.

## Remaining work

- Local main and fetched origin/main diverge by 5,479 and 6,497 commits. Do not rebase that unrelated history or force-push. Publication requires a separately agreed reconciliation path.
- Rerun the interrupted broad gate after settling the target checkout. Heterogeneous review also needs acpx.
- No host activation was run. The checkout includes unrelated NUC service changes, and publication is blocked.
- Linear OAuth login, macOS build/activation, and Darwin Herdr patch migration remain unverified.

## Commits

Local task commit: `feat(pi): upgrade to 1.0 with native MCP and codemode`, carrying this thread's Amp-Thread-ID. No remote publication or agent-work tag. The receipt remains active because delivery is blocked.
