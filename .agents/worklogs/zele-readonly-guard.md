---
purpose: Track the Zele outbound-mail safety guard.
applies_to: The local Zele Nix package and live account capabilities.
entrypoint: packages/zele/readonly-wrapper.sh
verification: Run wrapper tests, nix build .#zele, rebuild, then inspect live Zele capabilities and blocked commands.
update_when: Zele command routing or outbound-mail policy changes.
---

# Worklog: zele-readonly-guard

Status: complete

## Objective

Zele can read mail and create drafts but cannot send, reply, forward, unsubscribe by mail, or launch its send-capable TUI. Stop after source, package, and live runtime checks prove the guard.

## Decisions

- Remove `smtp` from current Zele account capabilities immediately; remove stored Fastmail SMTP configuration.
- Add a package wrapper so later login changes cannot restore outbound commands.
- Preserve draft creation and dry-run unsubscribe.
- Block the TUI because it exposes outbound actions outside CLI command parsing.

## Evidence

- Before: `zele whoami` showed `smtp` for Google and Fastmail.
- Immediate database update now shows Google `gmail, calendar` and Fastmail `imap`; Fastmail has no SMTP token object.
- `bun test packages/zele/readonly-wrapper.test.ts`: 1 pass, 35 assertions.
- `shellcheck packages/zele/readonly-wrapper.sh`: passed.
- Scoped `nix fmt`: 3 files formatted, 0 changed.
- `nix build ... .#zele` with the local `skills-catalog` override: passed.
- `darwin-rebuild switch` with the same override: passed; live Zele now resolves to `/nix/store/dsy0f8j20sxiz403qsyhc1dg6z2q2c1d-zele-0.4.0-unstable-2026-06-25/bin/zele`.
- Live `mail send`, direct `mail reply`, `mail forward`, `draft send`, and TUI smoke checks each exit 78 before reaching Zele; `mail list --limit 1` still succeeds.
- `hey check --worktree packages/zele` remains blocked by the pre-existing `/Users/edmundmiller/.config/dotfiles` flake input and missing prek config. The focused build, formatter, test, shellcheck, rebuild, and runtime checks exercised this change.
- `hey agent-audit-tests`: `PASS test-confidence`.
- `hey agent-finish`: worklog and agent-quality checks passed; aggregate `repo-quality` remained blocked by the same flake input and missing prek config.

## Reviews

- Plan review blocked: default reviewer returned `Authentication required`; `--reviewer gemini` closed the ACP connection. The user explicitly requested the guard; proceed with reversible, test-first implementation and retain the exact blocker.
- Landing review blocked: default and Gemini reviewers both returned `Authentication required`.

## Feedback

- Email preparation requests need a draft-first technical guard, not prompt interpretation alone.
- Root routing names `pkg-check`, but that command is absent from the live profile; focused package validation used `nix build .#zele`.

## Remaining work

- None for the requested guard. Heterogeneous review and aggregate repo-quality remain unavailable for the blockers recorded above.

## Commits

- `c2aa1ec` — regression test with strict expected-failure marker.
- `1039803cf` — read-only wrapper, package wiring, documentation, and live-guard worklog.
