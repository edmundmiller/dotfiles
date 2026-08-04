# Worklog: writer-computer

Status: complete

## Objective

Install Writer from writer.computer declaratively on MacTraitor-Pro and verify the signed app launches from the activated Darwin system. Stop when the package and host declaration are tested, activated, committed, pushed, and proven current with upstream.

## Decisions

- Package upstream Writer v0.4.0 from its signed Apple-silicon app archive. The Homebrew cask named `writer` is an unrelated, deprecated screenwriting application.
- Put the app in `pkgs.my.writer` and declare it in MacTraitor-Pro's system packages, following the existing native-app package pattern.
- Expose the app's built-in multi-call binary as `writer`; upstream intentionally switches to CLI mode when invoked through that command name.
- Pin the GitHub release asset by hash; version upgrades remain explicit dotfiles changes.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin 27.0.0, arm64.
- Upstream release API: v0.4.0, published 2026-07-20. The packaged `Writer.app.tar.gz` has upstream SHA-256 `61a4f13db19e2892c4b081db5c301bc3ae2bba00881bfd7e3c24ff05eda277a5`.
- Upstream README says Writer is a Tauri v2 local-first markdown editor and ships with a signed macOS release flow.
- The release archive's SHA-256 matches GitHub's published digest. `codesign --verify --deep --strict` passes, and Gatekeeper reports `accepted`, `source=Notarized Developer ID`, identifier `com.writer-computer`, team `BAQ8JZ4TZC`.
- Dedicated clean worktree: `/Users/emiller/.config/dotfiles.writer-computer`, branch `codex/writer-computer` from `origin/main`.
- Run receipt: `/Users/emiller/.local/state/dotfiles-agent-runs/5026d5506df9/20260804T212210Z-428bf3ccb7aa.json`.
- `nix build path:.#writer --no-link` built `/nix/store/8z1aj11p29gbadz30j0ld9ilhmm7snkn-writer-computer-0.4.0`.
- The built app passes strict code-signature and Gatekeeper assessment; its arm64 executable reports version 0.4.0.
- The packaged `writer --version` reports `writer 0.4.0`, and `writer --help` documents folder and Markdown-file launching.
- `hey check` passed all Darwin-compatible checks, including the MacTraitor-Pro configuration, package policy, package harness, and ast-grep suites.
- `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .` completed successfully.
- `/Applications/Nix Apps/Writer.app` reports bundle identifier `com.writer-computer`, version 0.4.0, passes Gatekeeper, launched successfully, and remained running under its expected bundle executable.
- `/run/current-system/sw/bin/writer` is active and reports `writer 0.4.0`; a fresh `hey check` and targeted `ast-grep scan packages/writer` pass after activation.
- `hey agent-audit-tests` passed test confidence. `hey agent-finish` passed the exercised Darwin checks, 33 agent-quality tests, instruction/rule checks, inventory checks, and worklog validation.

## Reviews

- Plan review: attempted with `hey agent-review plan --active-model-family gpt-5.6`; the reviewer failed at ACP session creation with `RUNTIME: Authentication required` before producing findings. Per the provider-auth guard, do not retry this route.
- Landing review: attempted with `hey agent-review landing --active-model-family gpt-5.6`; the reviewer again failed at ACP session creation with `RUNTIME: Authentication required` before producing findings.

## Feedback

None.

## Remaining work

None.

## Commits

- `bdae33224` — package Writer and enable it on MacTraitor-Pro.
- Worklog closeout is recorded in this commit. After landing, create annotated tag `agent-work/writer-computer`.
