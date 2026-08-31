# Worklog: repair-nuc-failed-units

Status: complete

## Objective

Restore the six failed units on the current NUC boot without mutating vault content or unrelated repository work. Stop when each unit is active/successful or is proved obsolete and reset, with current-boot logs and representative runtime checks.

## Decisions

- Authority is the requested live operational repair. The narrow Nix deployment and two regression-flow commits were required to correct the Home Manager failure; push remains unauthorized.
- Diagnose all six units from current-boot systemd records before restarting or changing state.
- Treat the Obsidian corruption guard as a safety boundary: never bypass it or edit the vault merely to make Sync start.

## Evidence

- Mac host verified as `MacTraitor-Pro.local`; NUC identity and current boot were verified before this work.
- Root cause for `home-manager-emiller`: Herdr returned `server_not_running`, which the activation treated as fatal instead of deferring until the runtime is available.
- The personal vault conflict was preserved as Git blob `0e8eef7f0d2a7efbe0171b6601b5d55dbcd223e0`, then replaced with the clean Mac Sync peer file. Both peers now hash to `480bd01546f0cb3b9fb43905556c5012bc4affcd144c9a6cb9a8af9ba192190a`.
- `mill-docs` was frozen, stashed recoverably at `928dc891614363c8002dfb1056166e8cfeecc261`, fast-forwarded to GitHub main `8c1b913639833989dc4f59544c1105d19a657af2`, and restored without unmerged entries. The resolved Granola file uses preserved full-record blob `dfeb1d57227996e9c50b8b4bb72dc59cdd4f5d80` (summary, backlinks, and 379-line transcript).
- Focused Herdr regression suite: `15 passed`. NUC `hey nuc-wt build` succeeded with system closure `/nix/store/4dw5qaymnyh30s245j9khfn690xc2zi4-nixos-system-nuc-26.11.20260714.18b9261`.
- The switch linked that closure and Home Manager completed successfully, explicitly logging that smart rename startup was deferred. The broader activation returned nonzero only because 1Password repeatedly rate-limited the Betty secret materializer; per provider-limit guardrails it was not retried.
- Final live readback: NUC state `running`, zero failed units, all six requested units report `Result=success`, both Sync services and all four related timers are active, and both Sync journals report `Fully synced`.
- Post-switch representative starts for `obsidian-sync-guard`, `obsidian-sync-healthcheck-ping`, and `mill-docs-git-pull` all returned `Result=success` and `ExecMainStatus=0`.

## Reviews

- Plan gate attempted with `hey agent-review plan --active-model-family openai`; ACP stopped at `session/new` with `RUNTIME: Authentication required` before producing findings. The user-authorized, evidence-first repair plan remains operative; do not retry the unavailable reviewer.

## Feedback

- None.

## Remaining work

- None for the live NUC repair. Publishing the two local commits is intentionally deferred because push was not authorized; until published, a future remote-source auto-upgrade will not contain the Herdr regression fix.

## Commits

- `fa90d6a54` `test(herdr): cover stopped runtime activation`
- `2cc3d4292` `fix(herdr): defer activation without server`
