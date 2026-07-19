# Worklog: asset-ownership-cleanup

Status: complete

## Objective

Keep the Mo shell module in dotfiles; make agents-workspace the source of truth for Betty Good Morning DJ prompt/helper assets while dotfiles retains only NUC service, secret, and Home Assistant wiring; remove the redundant untracked OpenWiki workflow from dotfiles because the Obsidian vault already owns the guarded workflow. Stop when both repositories are pushed, dotfiles pins the landed agents-workspace revision, NUC evaluation passes, and unrelated changes remain untouched.

## Decisions

- Keep `modules/shell/mo/default.nix` in dotfiles: it is host/package configuration and already landed cleanly.
- Export Betty DJ asset paths from `agents/betty/default.nix`; consume those paths through the existing `agents-workspace` flake input instead of hard-coding a second copy in dotfiles.
- Keep systemd, secret materialization, Home Assistant triggering, and NUC tests in dotfiles because they are host deployment truth.
- Delete the loose dotfiles OpenWiki workflow rather than copy it: `/Users/emiller/obsidian-vault/.github/workflows/openwiki-update.yml` is already the canonical guarded workflow.

## Evidence

- Dotfiles `main` commit `d970673101` introduced the Betty helper/prompt under `hosts/nuc/`; commit `8d96ab745d` completed the Mo module fix.
- Agents-workspace root ownership contract assigns canonical prompt/assets to `agents/<name>/` and host service wiring to dotfiles.
- Vault already contains `.github/workflows/openwiki-update.yml`, `.github/openwiki-ci-backend.js`, `.github/scripts/stage-openwiki-inbox.py`, and the shared local/CI launcher.
- Agents-workspace red check failed on missing `automations`; after exporting the Betty DJ paths and moving the assets, `nix build .#checks.aarch64-darwin.betty-good-morning-dj-assets --no-link` passed.
- `nix flake check --no-build` reached the unrelated existing Scintillate Telegram-topic deployment-input failure after evaluating the new Betty check.
- The two loose dotfiles OpenWiki workflow copies were moved to Trash; the vault workflow remains present.
- Authorized `npm run build` in `/Users/emiller/mill-docs/agents` passed and cleared the global agents-workspace hook without adding tracked mill-docs changes.
- Agents-workspace commit `7ff46d019bc59de7da044dea0d600d9bf855ceb5` landed on `main`; dotfiles now pins that exact revision.
- `hey nuc-wt build` built the NUC system from the relocated assets; `nix build .#checks.x86_64-linux.nuc-hermes-cron-executors --no-link` passed on the NUC.
- `hey agent-audit-tests` and `hey agent-finish --worklog .agents/worklogs/asset-ownership-cleanup.md` passed after bootstrapping the worktree's generated Prek config and accepting its focused formatter repair.
- `hey nuc` switched the NUC to `/nix/store/w0ivnwp5anrxkvy1izb6nw2qa3nbwxyf-nixos-system-nuc-26.11.20260714.18b9261`.
- Live `hermes-betty-good-morning-dj.service` is loaded and inactive/dead as expected for a oneshot; its wrapper references the relocated helper, whose live store SHA-256 matches the agents-workspace source (`cdc3196b92446fb9373fcb8ad8ec7eff456c6632b8063c55959c2ad64eab9ef1`). The job was not manually triggered.

## Reviews

- Plan review attempted with `hey agent-review plan --active-model-family gpt-5.6`; blocked by `RUNTIME: Authentication required`. Manual ownership review found the proposed exported-path seam matches both repositories' documented boundary.
- Landing review attempted with `hey agent-review landing --active-model-family gpt-5.6`; blocked by `RUNTIME: Authentication required`. Manual staged-diff review found only the ownership move, input pin, consumer/test update, and this worklog.

## Feedback

- Cross-repository agent assets need an explicit exported-path seam so host modules do not accumulate prompt/helper copies.

## Remaining work

- None.

## Commits

- agents-workspace: `7ff46d019bc59de7da044dea0d600d9bf855ceb5` (`refactor(betty): own Good Morning DJ assets`).
- dotfiles: `5388e10bc63fac6dff0f83a81009a96895c163f0` (`refactor(betty): source DJ assets from workspace`).
