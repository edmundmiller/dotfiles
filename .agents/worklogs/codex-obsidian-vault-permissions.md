# Worklog: codex-obsidian-vault-permissions

Status: complete

## Objective

Make NUC Codex sessions in `/home/emiller/obsidian-vault` write that repository, including Git state, while denying other local files and command network access. Stop after the active remote-control daemon loads the named project profile and boundary probes pass.

## Decisions

- Reuse the proven Codex 0.145 project permission pattern from `mill-docs`.
- Keep `.codex`, `.agents`, and `.qmd` read-only so the agent cannot widen its own policy or qmd scope.
- Keep command network disabled; preserve the vault's existing explicit MCP integrations.
- Do not grant `mill-docs` or other external paths without a separate need.

## Evidence

- The active remote-control daemon's Unix WebSocket accepted a thread with no client override and returned `activePermissionProfile = obsidian-vault`, `approvalPolicy = never`, and the vault cwd.
- Repository and `.git` writes persisted. Writes to `.codex`, `.agents`, and `.qmd` failed read-only; host Codex config was unreadable; an outside write did not persist.
- Command network access failed at DNS. The remote-control daemon restarted and reports `running`.
- A standalone app-server process launched qmd from `/home/emiller/obsidian-vault`; its project-local index contains nine vault collections, while `qmd://memory-root` from the global index is unavailable.
- Vault preflight, TOML parsing, patch hygiene, task-scoped `nix fmt -- --ci`, `hey agent-audit-tests`, and all 15 source agent-quality tests passed.
- The deployed profile hash matched the landed vault source; both task tips matched `origin/main` before this completion update.

## Reviews

Plan and landing reviews were attempted with `hey agent-review`; ACP session creation failed with `RUNTIME: Authentication required` before either produced review output.

## Feedback

The installed `hey agent-finish` closure still resolves `pkgs.jj` to the unrelated JSON editor, so one Jujutsu test fails there. The same 15-test suite passes from source with the real Jujutsu binary; this pre-existing dependency bug is already recorded in `codex-project-permissions.md`.

## Remaining work

None.

## Commits

- Vault `558713052b2065f73f574c28266d85055860a883` adds the active project profile and ownership policy.
- Dotfiles runbook, worklog, and completion evidence are this change.
