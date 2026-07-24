# Worklog: codex-project-permissions

Status: active

## Objective

Make NUC Codex remote sessions in `/home/emiller/mill-docs` write the repository (including Git state), read the separate Obsidian vault, and deny reads or persistent writes elsewhere. Stop after the active remote-control daemon loads the named profile and boundary probes pass.

## Decisions

- Use Codex 0.145 named permission profiles; legacy `workspace-write` still reads the whole host.
- Keep the vault read-only and keep `.codex`/`.agents` policy directories read-only.
- Keep command network disabled; Git commits work, but push/fetch remain an intentional host-side action.
- Disable inherited `fff` only because it bypasses the command filesystem sandbox. Keep MilDocs' explicit Granola and Linear MCP integrations; permission profiles do not constrain those remote services.
- Do not install system-wide `requirements.toml`; it would also constrain unrelated NUC Codex/Hermes workloads. Litter's observed iOS remote sessions currently inherit project defaults.

## Evidence

- A supported app-server thread loaded `activePermissionProfile = mill-docs` with no client override. Repository and `.git` writes persisted; the Obsidian vault was readable but not writable; host config was unreadable; outside writes did not persist; `.codex` stayed read-only.
- The same app-server path denied command network access (`curl` exited 6 because DNS was unavailable).
- The profile grants read-only access to the standalone Codex package tree because bundled Bubblewrap must execute that runtime.
- Recent `codex_chatgpt_ios_remote` sessions in MilDocs used inherited read-only defaults, confirming Litter did not supply a broader sandbox override.
- `hey nuc-wt build` completed on the NUC; task-scoped `nix fmt -- --ci` reported zero changes.
- The source `agent-quality-tests` suite passed all 15 tests.

## Reviews

Plan and landing reviews were attempted with `hey agent-review`; ACP session creation failed with `RUNTIME: Authentication required` before either produced review output. Source-backed Codex schema review, focused checks, and live 0.145 app-server probes remain the operative review evidence.

## Feedback

The installed `hey agent-finish` closure resolves `pkgs.jj` to the unrelated JSON stream editor, so its Jujutsu workspace test fails before exercising this change. The same 15-test suite passes from source with Jujutsu 0.37. This pre-existing package dependency belongs in a separate fix.

## Remaining work

Land and publish both repositories, then complete the run receipt.

## Commits

Pending.
