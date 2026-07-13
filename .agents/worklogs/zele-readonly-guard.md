---
purpose: Track the Zele outbound-mail safety guard.
applies_to: The local Zele Nix package and live account capabilities.
entrypoint: packages/zele/readonly-wrapper.sh
verification: Run wrapper tests, pkg-check zele, rebuild, then inspect live Zele capabilities and blocked commands.
update_when: Zele command routing or outbound-mail policy changes.
---

# Worklog: zele-readonly-guard

Status: active

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

## Reviews

- Plan review blocked: default reviewer returned `Authentication required`; `--reviewer gemini` closed the ACP connection. The user explicitly requested the guard; proceed with reversible, test-first implementation and retain the exact blocker.
- Landing review: pending.

## Feedback

- Email preparation requests need a draft-first technical guard, not prompt interpretation alone.

## Remaining work

- Landing review, commit, push, upstream verification, tag.

## Commits

- Pending.
